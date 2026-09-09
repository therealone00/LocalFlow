import Foundation

@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    private let userDefaultsKey = "LocalFlow_UserSettings"
    
    @Published public var settings: LocalFlowSettings {
        didSet {
            save()
        }
    }
    
    public init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(LocalFlowSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = LocalFlowSettings()
        }
    }
    
    public func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    public func resetToDefaults() {
        self.settings = LocalFlowSettings()
    }
}
