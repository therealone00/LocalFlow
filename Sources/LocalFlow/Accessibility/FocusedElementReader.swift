import Foundation
import ApplicationServices
import AppKit

public struct ElementContextInfo: Sendable {
    public let appName: String?
    public let bundleId: String?
    public let isSecureField: Bool
    public let precedingText: String?
}

public final class FocusedElementReader: @unchecked Sendable {
    public static let shared = FocusedElementReader()
    
    public init() {}
    
    /// Inspects the currently focused UI element system-wide.
    public func readCurrentContext(readPrecedingText: Bool = true) -> ElementContextInfo {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName
        let bundleId = frontApp?.bundleIdentifier
        
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElementValue: AnyObject?
        let copyResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementValue
        )
        
        guard copyResult == .success, let focusedElement = focusedElementValue else {
            return ElementContextInfo(
                appName: appName,
                bundleId: bundleId,
                isSecureField: false,
                precedingText: nil
            )
        }
        
        let element = focusedElement as! AXUIElement
        
        // Check if this is a secure/password field
        let isSecure = checkIfSecureField(element: element)
        
        var precedingText: String? = nil
        if readPrecedingText && !isSecure {
            precedingText = readCursorPrecedingText(element: element)
        }
        
        return ElementContextInfo(
            appName: appName,
            bundleId: bundleId,
            isSecureField: isSecure,
            precedingText: precedingText
        )
    }
    
    public func checkIfSecureField(element: AXUIElement) -> Bool {
        var subroleValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue) == .success,
           let subrole = subroleValue as? String {
            if subrole == "AXSecureTextField" || subrole.localizedCaseInsensitiveContains("secure") {
                return true
            }
        }
        
        var roleDescValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescValue) == .success,
           let roleDesc = roleDescValue as? String {
            if roleDesc.localizedCaseInsensitiveContains("secure") || roleDesc.localizedCaseInsensitiveContains("password") {
                return true
            }
        }
        
        return false
    }
    
    public func readCursorPrecedingText(element: AXUIElement) -> String? {
        var selectedRangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
              let value = selectedRangeValue,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        
        let rangeValue = value as! AXValue
        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range) else {
            return nil
        }
        
        guard range.location > 0 else {
            return nil
        }
        
        // Request up to 300 characters before the cursor
        let maxChars = 300
        let readStart = max(0, range.location - maxChars)
        let readLength = range.location - readStart
        var textRange = CFRange(location: readStart, length: readLength)
        
        guard let textRangeValue = AXValueCreate(.cfRange, &textRange) else {
            return nil
        }
        
        var precedingValue: AnyObject?
        let parameterizedResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            textRangeValue,
            &precedingValue
        )
        
        if parameterizedResult == .success, let precedingString = precedingValue as? String {
            return precedingString
        }
        
        return nil
    }
}
