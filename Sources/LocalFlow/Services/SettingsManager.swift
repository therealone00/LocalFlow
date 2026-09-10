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

    /// Settings with Pro-only choices downgraded for the free tier.
    ///
    /// The pipeline reads this rather than `settings`, so entitlement checks
    /// live in exactly one place instead of being scattered across the engines.
    /// The user's stored preference is left untouched, so buying Pro restores
    /// whatever they had picked without them having to set it again.
    public var effectiveSettings: LocalFlowSettings {
        guard !LicenseManager.shared.isPro else { return settings }

        var resolved = settings
        if resolved.intelligenceTier == .smart {
            resolved.intelligenceTier = .balanced
        }
        if resolved.speechModelTier == .small {
            resolved.speechModelTier = .base
        }
        resolved.useAppContext = false
        return resolved
    }
}
