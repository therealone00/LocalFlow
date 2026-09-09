import Foundation
import ApplicationServices
import AppKit

@MainActor
public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    @Published public private(set) var isTrusted: Bool = false
    private var timer: Timer?
    
    public init() {
        checkPermission()
        startPolling()
    }
    
    @discardableResult
    public func checkPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        if self.isTrusted != trusted {
            self.isTrusted = trusted
            AppLogger.accessibility.info("Accessibility permission status changed: \(trusted, privacy: .public)")
        }
        return trusted
    }
    
    public func promptForAccessibility() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        self.isTrusted = trusted
        if !trusted {
            openSystemSettings()
        }
    }
    
    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermission()
            }
        }
    }
}
