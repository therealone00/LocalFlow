import Foundation
import ApplicationServices
import AppKit

public final class TextInsertionEngine: @unchecked Sendable {
    public static let shared = TextInsertionEngine()
    
    public init() {}
    
    /// Inserts text into the currently active/focused application at the current cursor position.
    @MainActor
    public func insertText(_ text: String) async -> Bool {
        guard !text.isEmpty else { return true }
        
        AppLogger.accessibility.info("Attempting text insertion of length: \(text.count)")
        
        // Strategy 1: Direct Accessibility Injection
        if insertViaAccessibility(text) {
            AppLogger.accessibility.info("Direct Accessibility insertion succeeded.")
            return true
        }
        
        // Strategy 2: Universal Clipboard Fallback
        AppLogger.accessibility.info("Direct Accessibility fallback needed. Initiating clipboard injection.")
        return await insertViaClipboardFallback(text)
    }
    
    private func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElementValue: AnyObject?
        let copyResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementValue
        )
        
        guard copyResult == .success, let focusedElement = focusedElementValue else {
            return false
        }
        
        let element = focusedElement as! AXUIElement
        
        // Check if element is a secure text field (don't inject if in password field unless explicit)
        if FocusedElementReader.shared.checkIfSecureField(element: element) {
            AppLogger.accessibility.warning("Focused element is a secure/password field. Aborting insertion.")
            return false
        }
        
        // Try setting selected text attribute (replaces selection or inserts at cursor)
        let setResult = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        
        return setResult == .success
    }
    
    @MainActor
    private func insertViaClipboardFallback(_ text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        
        // 1. Backup existing pasteboard contents
        var backupItems: [(NSPasteboard.PasteboardType, Data)] = []
        if let items = pasteboard.pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        backupItems.append((type, data))
                    }
                }
            }
        }
        
        // 2. Put target text on pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 3. Synthesize Command+V key events explicitly
        let src = CGEventSource(stateID: .combinedSessionState)
        let cmdKeyCode: CGKeyCode = 0x37 // Command key
        let vKeyCode: CGKeyCode = 0x09   // 'v' key
        
        guard let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: cmdKeyCode, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: cmdKeyCode, keyDown: false) else {
            AppLogger.accessibility.error("Failed to create keyboard events for Cmd+V.")
            return false
        }
        
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        
        // Post to .cgSessionEventTap for user session GUI event delivery
        cmdDown.post(tap: .cgSessionEventTap)
        vDown.post(tap: .cgSessionEventTap)
        vUp.post(tap: .cgSessionEventTap)
        cmdUp.post(tap: .cgSessionEventTap)
        
        // 4. Safe delay before restoring pasteboard to allow target application (Safari, VS Code, Slack, Notes) to process the paste
        try? await Task.sleep(nanoseconds: 150_000_000) // 150 ms
        
        // 5. Restore original pasteboard items
        if !backupItems.isEmpty {
            pasteboard.clearContents()
            for (type, data) in backupItems {
                pasteboard.setData(data, forType: type)
            }
        }
        
        return true
    }
}
