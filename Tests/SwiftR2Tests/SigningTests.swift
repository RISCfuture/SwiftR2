import Testing
import Foundation
@testable import SwiftR2

// MARK: - Signing Key Tests

@Test
func testSigningKeyDerivation() {
    // Test case from AWS documentation
    let signingKey = SigningKey(
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
        date: "20150830",
        region: "us-east-1",
        service: "iam"
    )

    #expect(signingKey.date == "20150830")
    #expect(signingKey.region == "us-east-1")
    #expect(signingKey.service == "iam")
    #expect(signingKey.credentialScope == "20150830/us-east-1/iam/aws4_request")
}

@Test
func testSigningKeyForR2() {
    let signingKey = SigningKey(
        secretAccessKey: "test-secret-key",
        date: "20240115",
        region: "auto",
        service: "s3"
    )

    #expect(signingKey.region == "auto")
    #expect(signingKey.service == "s3")
    #expect(signingKey.credentialScope == "20240115/auto/s3/aws4_request")
}

// MARK: - Canonical Request Tests

@Test
func testCanonicalRequestFromURLRequest() {
    let url = URL(string: "https://example.r2.cloudflarestorage.com/bucket/test.txt")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("example.r2.cloudflarestorage.com", forHTTPHeaderField: "Host")
    request.setValue("20240115T120000Z", forHTTPHeaderField: "x-amz-date")
    request.setValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")

    let canonical = CanonicalRequest(
        request: request,
        payload: nil,
        signedHeaderNames: ["host", "x-amz-content-sha256", "x-amz-date"]
    )

    #expect(canonical.method == "GET")
    #expect(canonical.canonicalURI == "/bucket/test.txt")
    #expect(canonical.signedHeaders == "host;x-amz-content-sha256;x-amz-date")
}

@Test
func testCanonicalQueryString() {
    let url = URL(string: "https://example.com/bucket?prefix=test&max-keys=100&delimiter=/")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("example.com", forHTTPHeaderField: "Host")

    let canonical = CanonicalRequest(
        request: request,
        payload: nil,
        signedHeaderNames: ["host"]
    )

    // Query parameters should be sorted alphabetically
    #expect(canonical.canonicalQueryString.contains("delimiter"))
    #expect(canonical.canonicalQueryString.contains("max-keys"))
    #expect(canonical.canonicalQueryString.contains("prefix"))
}

@Test
func testPayloadHash() {
    let testPayload = Data("Hello, World!".utf8)
    let hash = CanonicalRequest.sha256Hash(testPayload)

    // SHA-256 hash of "Hello, World!" in lowercase hex
    #expect(hash == "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f")
}

@Test
func testEmptyPayloadHash() {
    let hash = CanonicalRequest.sha256Hash(Data())

    // SHA-256 hash of empty string
    #expect(hash == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
}

@Test
func testURIEncoding() {
    // Test basic URI encoding
    let encoded = CanonicalRequest.uriEncode("hello world", encodeSlash: true)
    #expect(encoded == "hello%20world")

    // Test that slashes are preserved when encodeSlash is false
    let pathEncoded = CanonicalRequest.uriEncode("/bucket/folder/file.txt", encodeSlash: false)
    #expect(pathEncoded == "/bucket/folder/file.txt")

    // Test that slashes are encoded when encodeSlash is true
    let fullEncoded = CanonicalRequest.uriEncode("/bucket/folder", encodeSlash: true)
    #expect(fullEncoded == "%2Fbucket%2Ffolder")
}

// MARK: - AWS Signature V4 Tests

@Test
func testAWSSignatureV4Signing() {
    let credentials = R2Credentials(
        accessKeyId: "AKIAIOSFODNN7EXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    )

    let signer = AWSSignatureV4(
        credentials: credentials,
        region: "auto",
        service: "s3"
    )

    let url = URL(string: "https://test.r2.cloudflarestorage.com/bucket/key")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let signedRequest = signer.sign(
        request: request,
        payload: nil,
        date: Date(timeIntervalSince1970: 1705320000) // Fixed date for testing
    )

    // Verify required headers are present
    #expect(signedRequest.value(forHTTPHeaderField: "Authorization") != nil)
    #expect(signedRequest.value(forHTTPHeaderField: "x-amz-date") != nil)
    #expect(signedRequest.value(forHTTPHeaderField: "x-amz-content-sha256") != nil)
    #expect(signedRequest.value(forHTTPHeaderField: "Host") != nil)

    // Verify Authorization header format
    let auth = signedRequest.value(forHTTPHeaderField: "Authorization")!
    #expect(auth.hasPrefix("AWS4-HMAC-SHA256"))
    #expect(auth.contains("Credential=AKIAIOSFODNN7EXAMPLE"))
    #expect(auth.contains("SignedHeaders="))
    #expect(auth.contains("Signature="))
}

@Test
func testPresignedURLGeneration() {
    let credentials = R2Credentials(
        accessKeyId: "AKIAIOSFODNN7EXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    )

    let signer = AWSSignatureV4(
        credentials: credentials,
        region: "auto",
        service: "s3"
    )

    let baseURL = URL(string: "https://test.r2.cloudflarestorage.com/bucket/key")!
    let presignedURL = signer.presignedURL(
        url: baseURL,
        method: "GET",
        expiration: 3600,
        date: Date(timeIntervalSince1970: 1705320000)
    )

    let urlString = presignedURL.absoluteString

    // Verify required query parameters
    #expect(urlString.contains("X-Amz-Algorithm=AWS4-HMAC-SHA256"))
    #expect(urlString.contains("X-Amz-Credential="))
    #expect(urlString.contains("X-Amz-Date="))
    #expect(urlString.contains("X-Amz-Expires=3600"))
    #expect(urlString.contains("X-Amz-SignedHeaders="))
    #expect(urlString.contains("X-Amz-Signature="))
}

@Test
func testPresignedPutURL() {
    let credentials = R2Credentials(
        accessKeyId: "test-access-key",
        secretAccessKey: "test-secret-key"
    )

    let signer = AWSSignatureV4(
        credentials: credentials,
        region: "auto",
        service: "s3"
    )

    let baseURL = URL(string: "https://test.r2.cloudflarestorage.com/bucket/upload.txt")!
    let presignedURL = signer.presignedURL(
        url: baseURL,
        method: "PUT",
        expiration: 1800,
        date: Date(timeIntervalSince1970: 1705320000),
        additionalHeaders: ["content-type": "text/plain"]
    )

    let urlString = presignedURL.absoluteString
    #expect(urlString.contains("X-Amz-Expires=1800"))
    #expect(urlString.contains("X-Amz-SignedHeaders=content-type"))
}
