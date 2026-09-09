import Foundation
import ApplicationServices
import AppKit

public final class TextInsertionEngine: @unchecked Sendable {
    public static let shared = TextInsertionEngine()
    
    public init() {}
    
    /// Inserts text into the currently active/focused application at the current cursor position.
    @MainActor
    public func insertText(_ text: String, targetApp: NSRunningApplication? = nil) async -> Bool {
        guard !text.isEmpty else { return true }
        
        AppLogger.accessibility.info("Attempting text insertion of length: \(text.count)")
        
        // 1. Reactivate the target application if needed (e.g. if dictation was triggered from menu bar)
        if let app = targetApp, app.bundleIdentifier != Bundle.main.bundleIdentifier {
            app.activate()
            // Allow window server a brief moment to restore keyboard focus
            try? await Task.sleep(nanoseconds: 70_000_000) // 70ms
        }
        
        // 2. Always put target text on pasteboard as universal baseline
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 3. Strategy 1: Direct Accessibility Injection
        if AccessibilityManager.shared.isTrusted && insertViaAccessibility(text) {
            AppLogger.accessibility.info("Direct Accessibility insertion succeeded.")
            return true
        }
        
        // 4. Strategy 2: Universal Synthesized Cmd+V Fallback
        if AccessibilityManager.shared.isTrusted {
            AppLogger.accessibility.info("Direct Accessibility fallback needed. Initiating clipboard Cmd+V injection.")
            return await insertViaClipboardFallback()
        } else {
            AppLogger.accessibility.warning("Accessibility permission missing. Text copied to clipboard for manual paste.")
            return false
        }
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
    private func insertViaClipboardFallback() async -> Bool {
        // Synthesize Command+V key events explicitly
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09   // 'v' key
        
        guard let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) else {
            AppLogger.accessibility.error("Failed to create keyboard events for Cmd+V.")
            return false
        }
        
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        
        // Post to .cgSessionEventTap for user session GUI event delivery
        vDown.post(tap: .cgSessionEventTap)
        vUp.post(tap: .cgSessionEventTap)
        
        AppLogger.accessibility.info("Synthesized Cmd+V event posted successfully.")
        return true
    }
}
