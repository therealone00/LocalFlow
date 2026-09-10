import XCTest
import CryptoKit
@testable import LocalFlow

/// The verifier is the only thing standing between the free and paid tiers, so
/// it is tested against a throwaway keypair rather than the shipping one.
final class LicenseVerifierTests: XCTestCase {

    private var signingKey: Curve25519.Signing.PrivateKey!
    private var publicKeyBase64: String!

    override func setUp() {
        super.setUp()
        signingKey = Curve25519.Signing.PrivateKey()
        publicKeyBase64 = signingKey.publicKey.rawRepresentation.base64EncodedString()
    }

    // MARK: - Helpers

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeKey(
        version: Int = 1,
        product: String = "pro",
        email: String = "buyer@example.com",
        orderId: String = "cs_test_123",
        signWith key: Curve25519.Signing.PrivateKey? = nil
    ) throws -> String {
        let payload = """
        {"v":\(version),"p":"\(product)","e":"\(email)","o":"\(orderId)","t":1789000000}
        """
        let payloadData = Data(payload.utf8)
        let signature = try (key ?? signingKey).signature(for: payloadData)
        return "LF1.\(base64URL(payloadData)).\(base64URL(signature))"
    }

    // MARK: - Accepting

    func testValidKeyIsAccepted() throws {
        let key = try makeKey()
        let result = LicenseVerifier.verify(key, publicKeyBase64: publicKeyBase64)

        guard case .success(let license) = result else {
            return XCTFail("Expected a valid license, got \(result)")
        }
        XCTAssertTrue(license.isPro)
        XCTAssertEqual(license.email, "buyer@example.com")
        XCTAssertEqual(license.orderId, "cs_test_123")
    }

    func testSurroundingWhitespaceAndLineBreaksAreTolerated() throws {
        let key = try makeKey()
        let messy = "  \n \(key.prefix(20))\n\(key.dropFirst(20)) \n "
        let result = LicenseVerifier.verify(messy, publicKeyBase64: publicKeyBase64)
        XCTAssertNoThrow(try result.get(), "Keys pasted out of an email must still activate")
    }

    // MARK: - Rejecting

    func testKeySignedByAnotherKeypairIsRejected() throws {
        let attacker = Curve25519.Signing.PrivateKey()
        let key = try makeKey(signWith: attacker)

        let result = LicenseVerifier.verify(key, publicKeyBase64: publicKeyBase64)
        XCTAssertEqual(result.failureError, .signatureInvalid)
    }

    func testTamperedPayloadIsRejected() throws {
        // Re-issue the same signature over a payload that grants a different tier.
        let key = try makeKey()
        let parts = key.dropFirst("LF1.".count).split(separator: ".")
        let forgedPayload = Data(#"{"v":1,"p":"pro","e":"attacker@example.com","o":"free","t":1789000000}"#.utf8)
        let forged = "LF1.\(base64URL(forgedPayload)).\(parts[1])"

        let result = LicenseVerifier.verify(forged, publicKeyBase64: publicKeyBase64)
        XCTAssertEqual(result.failureError, .signatureInvalid)
    }

    func testEmptyKeyReportsSomethingActionable() {
        XCTAssertEqual(LicenseVerifier.verify("").failureError, .empty)
    }

    func testKeyWithoutPrefixIsMalformed() {
        XCTAssertEqual(LicenseVerifier.verify("not-a-license").failureError, .malformed)
    }

    func testTruncatedKeyIsMalformed() throws {
        let key = try makeKey()
        let truncated = String(key.prefix(key.count / 2))
        let result = LicenseVerifier.verify(truncated, publicKeyBase64: publicKeyBase64)
        XCTAssertNotNil(result.failureError, "A half-copied key must never validate")
    }

    func testFutureVersionIsRejectedRatherThanMisread() throws {
        let key = try makeKey(version: 99)
        let result = LicenseVerifier.verify(key, publicKeyBase64: publicKeyBase64)
        XCTAssertEqual(result.failureError, .unsupportedVersion(99))
    }

    // MARK: - Shipping configuration

    func testShippingPublicKeyIsPresentAndWellFormed() throws {
        let data = try XCTUnwrap(
            Data(base64Encoded: LicenseVerifier.publicKeyBase64),
            "The embedded public key must be valid base64"
        )
        XCTAssertEqual(data.count, 32, "Ed25519 public keys are 32 bytes")
        XCTAssertNoThrow(try Curve25519.Signing.PublicKey(rawRepresentation: data))
    }
}

private extension Result where Failure == LicenseError {
    var failureError: LicenseError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
