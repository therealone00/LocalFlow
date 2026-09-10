import Foundation

/// A verified LocalFlow Pro license.
public struct License: Codable, Equatable, Sendable {
    /// Payload version, so older apps can refuse keys they do not understand.
    public let version: Int
    /// Product tier. Currently only "pro".
    public let product: String
    /// The email the license was issued to, shown back in Settings.
    public let email: String
    /// The Stripe checkout session the license came from, for support lookups.
    public let orderId: String
    /// Issue date, seconds since epoch.
    public let issuedAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case product = "p"
        case email = "e"
        case orderId = "o"
        case issuedAt = "t"
    }

    public var issueDate: Date { Date(timeIntervalSince1970: issuedAt) }

    public var isPro: Bool { product == "pro" }

    /// Email with the local part shortened, for display in a UI that other
    /// people might be looking at.
    public var maskedEmail: String {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2, let local = parts.first, let domain = parts.last else {
            return email
        }
        let visible = local.prefix(2)
        return "\(visible)\(String(repeating: "•", count: max(1, local.count - 2)))@\(domain)"
    }
}

/// Why a license key was rejected. Every case maps to a message a person can
/// act on, because "invalid license" tells a paying customer nothing.
public enum LicenseError: Error, Equatable, Sendable {
    case empty
    case malformed
    case unsupportedVersion(Int)
    case signatureInvalid
    case notConfigured

    public var message: String {
        switch self {
        case .empty:
            return "Paste the license key from your purchase confirmation."
        case .malformed:
            return "That does not look like a LocalFlow license key. It starts with “LF1.” and is one long line."
        case .unsupportedVersion:
            return "This key was issued for a newer version of LocalFlow. Update the app and try again."
        case .signatureInvalid:
            return "This key could not be verified. Check that you copied all of it, including the end."
        case .notConfigured:
            return "This build cannot verify licenses. It was compiled without a signing key."
        }
    }
}
