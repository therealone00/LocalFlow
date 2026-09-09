import Foundation
import AVFoundation
import AppKit

@MainActor
public final class MicrophoneAccessManager: ObservableObject {
    public static let shared = MicrophoneAccessManager()
    
    @Published public private(set) var isGranted: Bool = false
    
    public init() {
        checkPermission()
    }
    
    public func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            self.isGranted = true
        case .notDetermined, .denied, .restricted:
            self.isGranted = false
        @unknown default:
            self.isGranted = false
        }
    }
    
    public func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            self.isGranted = true
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            self.isGranted = granted
            return granted
        case .denied, .restricted:
            self.isGranted = false
            openSystemSettings()
            return false
        @unknown default:
            self.isGranted = false
            return false
        }
    }
    
    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
