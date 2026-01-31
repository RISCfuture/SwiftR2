import Foundation
@preconcurrency import CryptoKit

/// A signing key derived for AWS Signature V4.
struct SigningKey: Sendable {
    /// The derived signing key.
    let key: SymmetricKey

    /// The date the key was derived for.
    let date: String

    /// The region the key was derived for.
    let region: String

    /// The service the key was derived for.
    let service: String

    /// The credential scope string.
    var credentialScope: String {
        "\(date)/\(region)/\(service)/aws4_request"
    }

    /// Derives a signing key from a secret access key.
    /// - Parameters:
    ///   - secretAccessKey: The secret access key.
    ///   - date: The date stamp (YYYYMMDD format).
    ///   - region: The region (e.g., "auto" for R2).
    ///   - service: The service name (e.g., "s3").
    init(secretAccessKey: String, date: String, region: String, service: String) {
        // kDate = HMAC-SHA256("AWS4" + secretKey, dateStamp)
        let kSecret = "AWS4" + secretAccessKey
        let kDate = Self.hmacSHA256(key: Data(kSecret.utf8), data: Data(date.utf8))

        // kRegion = HMAC-SHA256(kDate, region)
        let kRegion = Self.hmacSHA256(key: kDate, data: Data(region.utf8))

        // kService = HMAC-SHA256(kRegion, service)
        let kService = Self.hmacSHA256(key: kRegion, data: Data(service.utf8))

        // kSigning = HMAC-SHA256(kService, "aws4_request")
        let kSigning = Self.hmacSHA256(key: kService, data: Data("aws4_request".utf8))

        self.key = SymmetricKey(data: kSigning)
        self.date = date
        self.region = region
        self.service = service
    }

    /// Computes HMAC-SHA256.
    private static func hmacSHA256(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(signature)
    }

    /// Signs data using this signing key.
    /// - Parameter data: The data to sign.
    /// - Returns: The signature as a hex string.
    func sign(_ data: Data) -> String {
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }
}
