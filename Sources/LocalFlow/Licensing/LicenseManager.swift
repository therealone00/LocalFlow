import Foundation
import Combine

/// Holds the current license and exposes what the app is allowed to do.
@MainActor
public final class LicenseManager: ObservableObject {
    public static let shared = LicenseManager()

    private static let storageKey = "LocalFlow_License"

    /// The verified license, or `nil` on the free tier.
    @Published public private(set) var license: License?

    public var isPro: Bool { license?.isPro == true }

    public init() {
        load()
    }

    // MARK: - Activation

    /// Verifies and stores a license key. The stored value is the key itself,
    /// re-verified on every launch, so tampering with the stored file just
    /// makes the license stop validating.
    @discardableResult
    public func activate(key: String) -> Result<License, LicenseError> {
        let result = LicenseVerifier.verify(key)
        if case .success(let license) = result {
            UserDefaults.standard.set(
                key.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: Self.storageKey
            )
            self.license = license
            AppLogger.app.info("Pro license activated (order \(license.orderId, privacy: .public))")
        }
        return result
    }

    public func deactivate() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        license = nil
        AppLogger.app.info("Pro license removed from this Mac.")
    }

    private func load() {
        guard let stored = UserDefaults.standard.string(forKey: Self.storageKey) else { return }
        if case .success(let license) = LicenseVerifier.verify(stored) {
            self.license = license
        } else {
            // A key that no longer verifies is dropped rather than kept around
            // in a half-valid state.
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
    }

    // MARK: - Entitlements

    public func isUnlocked(_ feature: ProFeature) -> Bool {
        isPro
    }

    /// Free-tier ceiling for a countable feature, or `nil` when unlimited.
    public func limit(for feature: ProFeature) -> Int? {
        guard !isPro else { return nil }
        return feature.freeLimit
    }
}
