import Foundation
import CryptoKit

/// AWS Signature Version 4 request signing.
///
/// Implements the AWS Signature Version 4 signing process for authenticating
/// requests to S3-compatible services like Cloudflare R2.
///
/// Most users don't need to use this directly; ``R2Client`` handles
/// signing automatically. This is exposed for advanced use cases like
/// custom request signing or presigned URL generation.
///
/// ```swift
/// let signer = AWSSignatureV4(
///     credentials: credentials,
///     region: "auto",
///     service: "s3"
/// )
///
/// // Sign a request
/// let signedRequest = signer.sign(request: request, payload: body)
///
/// // Generate a presigned URL
/// let url = signer.presignedURL(url: objectURL, expiration: 3600)
/// ```
public struct AWSSignatureV4: Sendable {
    private let credentials: R2Credentials
    private let region: String
    private let service: String

    /// Creates a new request signer.
    ///
    /// - Parameters:
    ///   - credentials: The credentials for signing.
    ///   - region: The AWS region. Use `"auto"` for Cloudflare R2.
    ///   - service: The service name. Use `"s3"` for R2.
    public init(
        credentials: R2Credentials,
        region: String = "auto",
        service: String = "s3"
    ) {
        self.credentials = credentials
        self.region = region
        self.service = service
    }

    /// Formats a date for AWS Signature V4.
    /// - Parameter date: The date to format.
    /// - Returns: A tuple of (amzDate, dateStamp) in AWS format.
    private static func formatDate(_ date: Date) -> (amzDate: String, dateStamp: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let amzDate = formatter.string(from: date)
        let dateStamp = String(amzDate.prefix(8))

        return (amzDate, dateStamp)
    }

    /// Signs a URL request with AWS Signature V4.
    ///
    /// Adds the required `Authorization`, `x-amz-date`, and `x-amz-content-sha256`
    /// headers for authenticated requests.
    ///
    /// - Parameters:
    ///   - request: The request to sign.
    ///   - payload: The request body data, or `nil` for requests without a body.
    ///   - date: The timestamp for signing. Defaults to the current time.
    /// - Returns: A new request with authentication headers added.
    public func sign(
        request: URLRequest,
        payload: Data?,
        date: Date = Date()
    ) -> URLRequest {
        var signedRequest = request

        // Format dates - AWS requires YYYYMMDDTHHMMSSZ format
        let (amzDate, dateStamp) = Self.formatDate(date)

        // Compute payload hash
        let payloadHash = CanonicalRequest.sha256Hash(payload ?? Data())

        // Set required headers
        signedRequest.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        signedRequest.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        if let host = request.url?.host {
            signedRequest.setValue(host, forHTTPHeaderField: "Host")
        }

        // Determine which headers to sign
        var signedHeaderNames = ["host", "x-amz-content-sha256", "x-amz-date"]

        // Include content-type if present
        if request.value(forHTTPHeaderField: "Content-Type") != nil {
            signedHeaderNames.append("content-type")
        }

        // Include content-length if present
        if request.value(forHTTPHeaderField: "Content-Length") != nil {
            signedHeaderNames.append("content-length")
        }

        // Include any x-amz-* headers
        if let allHeaders = signedRequest.allHTTPHeaderFields {
            for key in allHeaders.keys {
                let lowercased = key.lowercased()
                if lowercased.hasPrefix("x-amz-") && !signedHeaderNames.contains(lowercased) {
                    signedHeaderNames.append(lowercased)
                }
            }
        }

        // Create canonical request
        let canonicalRequest = CanonicalRequest(
            request: signedRequest,
            payload: payload,
            signedHeaderNames: signedHeaderNames
        )

        // Create string to sign
        let stringToSign = createStringToSign(
            date: amzDate,
            dateStamp: dateStamp,
            canonicalRequestHash: canonicalRequest.hash
        )

        // Derive signing key and sign
        let signingKey = SigningKey(
            secretAccessKey: credentials.secretAccessKey,
            date: dateStamp,
            region: region,
            service: service
        )

        let signature = signingKey.sign(Data(stringToSign.utf8))

        // Create authorization header
        let authorizationHeader = [
            "AWS4-HMAC-SHA256 Credential=\(credentials.accessKeyId)/\(signingKey.credentialScope)",
            "SignedHeaders=\(canonicalRequest.signedHeaders)",
            "Signature=\(signature)"
        ].joined(separator: ", ")

        signedRequest.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")

        return signedRequest
    }

    /// Creates a presigned URL for unauthenticated access.
    ///
    /// Generates a URL with embedded authentication that can be used
    /// without credentials for the specified duration.
    ///
    /// - Parameters:
    ///   - url: The base URL to sign.
    ///   - method: The HTTP method. Defaults to `"GET"`.
    ///   - expiration: Validity duration in seconds. Defaults to 3600 (1 hour).
    ///     Maximum is 604800 (7 days).
    ///   - date: The timestamp for signing. Defaults to the current time.
    ///   - additionalHeaders: Extra headers to include in the signature.
    /// - Returns: A presigned URL with authentication query parameters.
    public func presignedURL(
        url: URL,
        method: String = "GET",
        expiration: TimeInterval = 3600,
        date: Date = Date(),
        additionalHeaders: [String: String] = [:]
    ) -> URL {
        // Format dates - AWS requires YYYYMMDDTHHMMSSZ format
        let (amzDate, dateStamp) = Self.formatDate(date)

        // Build credential scope
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let credential = "\(credentials.accessKeyId)/\(credentialScope)"

        // Build headers dict
        var headers = additionalHeaders
        if let host = url.host {
            headers["host"] = host
        }

        let signedHeaderNames = headers.keys.map { $0.lowercased() }.sorted()
        let signedHeaders = signedHeaderNames.joined(separator: ";")

        // Build query parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []

        queryItems.append(contentsOf: [
            URLQueryItem(name: "X-Amz-Algorithm", value: "AWS4-HMAC-SHA256"),
            URLQueryItem(name: "X-Amz-Credential", value: credential),
            URLQueryItem(name: "X-Amz-Date", value: amzDate),
            URLQueryItem(name: "X-Amz-Expires", value: String(Int(expiration))),
            URLQueryItem(name: "X-Amz-SignedHeaders", value: signedHeaders)
        ])

        // Sort query items for canonical request
        queryItems.sort { $0.name < $1.name }
        components.queryItems = queryItems

        let urlWithQuery = components.url!

        // Create canonical request
        let canonicalRequest = CanonicalRequest(
            method: method,
            url: urlWithQuery,
            headers: headers,
            signedHeaderNames: signedHeaderNames,
            hashedPayload: "UNSIGNED-PAYLOAD"
        )

        // Create string to sign
        let stringToSign = createStringToSign(
            date: amzDate,
            dateStamp: dateStamp,
            canonicalRequestHash: canonicalRequest.hash
        )

        // Sign
        let signingKey = SigningKey(
            secretAccessKey: credentials.secretAccessKey,
            date: dateStamp,
            region: region,
            service: service
        )

        let signature = signingKey.sign(Data(stringToSign.utf8))

        // Add signature to URL
        queryItems.append(URLQueryItem(name: "X-Amz-Signature", value: signature))
        components.queryItems = queryItems

        return components.url!
    }

    /// Creates the string to sign.
    private func createStringToSign(
        date: String,
        dateStamp: String,
        canonicalRequestHash: String
    ) -> String {
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"

        return [
            "AWS4-HMAC-SHA256",
            date,
            credentialScope,
            canonicalRequestHash
        ].joined(separator: "\n")
    }
}
