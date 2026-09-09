import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public private(set) var isEnabled: Bool = false
    
    public init() {
        checkStatus()
    }
    
    public func checkStatus() {
        let status = SMAppService.mainApp.status
        self.isEnabled = (status == .enabled)
    }
    
    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            checkStatus()
            AppLogger.app.info("Launch at login set to: \(enabled, privacy: .public)")
        } catch {
            AppLogger.app.error("Failed to configure Launch at Login via SMAppService: \(error.localizedDescription)")
        }
    }
}
