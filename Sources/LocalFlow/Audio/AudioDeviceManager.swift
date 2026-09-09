import Foundation
import CoreAudio
import AVFoundation

public struct AudioInputDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let isDefault: Bool
}

@MainActor
public final class AudioDeviceManager: ObservableObject {
    public static let shared = AudioDeviceManager()
    
    @Published public private(set) var availableDevices: [AudioInputDevice] = []
    
    public init() {
        refreshDevices()
    }
    
    public func refreshDevices() {
        var devices: [AudioInputDevice] = [
            AudioInputDevice(id: "default", name: "System Default", isDefault: true)
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        
        for device in discoverySession.devices {
            devices.append(AudioInputDevice(id: device.uniqueID, name: device.localizedName, isDefault: false))
        }
        
        self.availableDevices = devices
    }
}
