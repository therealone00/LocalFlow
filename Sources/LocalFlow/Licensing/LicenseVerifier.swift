import Foundation
import CryptoKit

/// Verifies license keys entirely offline.
///
/// A key is `LF1.<base64url payload>.<base64url signature>`. The signature is
/// Ed25519 over the raw payload bytes, checked against a public key compiled
/// into the app. Nothing is sent anywhere — a licensing check that phoned home
/// would contradict the one promise this app makes.
public enum LicenseVerifier {

    /// Public half of the license signing keypair. The private half lives only
    /// in the Cloudflare Worker's secret store.
    public static let publicKeyBase64 = "fxw50XLyEmCZCNiIipD7zNVq/q7E2uF20chT2w5opf0="

    public static let keyPrefix = "LF1."
    public static let supportedVersion = 1

    /// - Parameter publicKeyBase64: overridable so the test suite can sign with
    ///   a throwaway keypair instead of shipping a private key in the repo.
    public static func verify(
        _ rawKey: String,
        publicKeyBase64: String = LicenseVerifier.publicKeyBase64
    ) -> Result<License, LicenseError> {
        let key = rawKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !key.isEmpty else { return .failure(.empty) }
        guard key.hasPrefix(keyPrefix) else { return .failure(.malformed) }

        let parts = key.dropFirst(keyPrefix.count).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let payloadData = Data(base64URLEncoded: String(parts[0])),
              let signatureData = Data(base64URLEncoded: String(parts[1])) else {
            return .failure(.malformed)
        }

        guard let publicKeyData = Data(base64Encoded: publicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData) else {
            return .failure(.notConfigured)
        }

        // Signature first: never decode a payload we have not authenticated.
        guard publicKey.isValidSignature(signatureData, for: payloadData) else {
            return .failure(.signatureInvalid)
        }

        guard let license = try? JSONDecoder().decode(License.self, from: payloadData) else {
            return .failure(.malformed)
        }

        guard license.version <= supportedVersion else {
            return .failure(.unsupportedVersion(license.version))
        }

        return .success(license)
    }
}

extension Data {
    /// Decodes base64url (RFC 4648 §5), which is what the Worker emits so that
    /// keys survive being pasted through URLs and email clients.
    init?(base64URLEncoded input: String) {
        var base64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        self.init(base64Encoded: base64)
    }
}
