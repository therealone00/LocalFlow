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
        AppLogger.accessibility.info("Direct Accessibility failed or unsupported. Falling back to clipboard injection.")
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
        
        // Check if element is a secure text field (don't inject if user is in password field unless explicit)
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
        
        // 3. Post Command+V key events
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09 // Virtual keycode for 'v'
        
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) else {
            AppLogger.accessibility.error("Failed to create keyboard events for Cmd+V.")
            return false
        }
        
        keyDown.flags = .maskCommand
        keyUp.flags = []
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        
        // 4. Delay before restoring pasteboard to allow target application to process paste event
        try? await Task.sleep(nanoseconds: 80_000_000) // 80 ms
        
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
