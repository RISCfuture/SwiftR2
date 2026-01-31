import Foundation
import CryptoKit

/// Builds a canonical request for AWS Signature V4.
struct CanonicalRequest: Sendable {
    /// The HTTP method.
    let method: String

    /// The canonical URI (URL-encoded path).
    let canonicalURI: String

    /// The canonical query string.
    let canonicalQueryString: String

    /// The canonical headers string.
    let canonicalHeaders: String

    /// The signed headers string.
    let signedHeaders: String

    /// The hashed payload.
    let hashedPayload: String

    /// The canonical request string.
    var string: String {
        [
            method,
            canonicalURI,
            canonicalQueryString,
            canonicalHeaders,
            signedHeaders,
            hashedPayload
        ].joined(separator: "\n")
    }

    /// The hash of the canonical request.
    var hash: String {
        Self.sha256Hash(Data(string.utf8))
    }

    /// Creates a canonical request from a URL request.
    /// - Parameters:
    ///   - request: The URL request.
    ///   - payload: The request payload.
    ///   - signedHeaderNames: The headers to include in signing.
    init(request: URLRequest, payload: Data?, signedHeaderNames: [String]) {
        self.method = request.httpMethod ?? "GET"

        // Canonical URI - the URL-encoded path
        let path = request.url?.path ?? "/"
        self.canonicalURI = path.isEmpty ? "/" : Self.uriEncode(path, encodeSlash: false)

        // Canonical query string - sorted by parameter name
        self.canonicalQueryString = Self.canonicalQueryString(from: request.url)

        // Build canonical headers and signed headers
        let sortedHeaderNames = signedHeaderNames.map { $0.lowercased() }.sorted()
        var headersDict: [String: String] = [:]

        if let allHeaders = request.allHTTPHeaderFields {
            for (key, value) in allHeaders {
                headersDict[key.lowercased()] = value.trimmingCharacters(in: .whitespaces)
            }
        }

        // Add host if not present
        if headersDict["host"] == nil, let host = request.url?.host {
            headersDict["host"] = host
        }

        var canonicalHeadersBuilder = ""
        for name in sortedHeaderNames {
            if let value = headersDict[name] {
                canonicalHeadersBuilder += "\(name):\(value)\n"
            }
        }

        self.canonicalHeaders = canonicalHeadersBuilder
        self.signedHeaders = sortedHeaderNames.joined(separator: ";")

        // Hashed payload
        self.hashedPayload = Self.sha256Hash(payload ?? Data())
    }

    /// Creates a canonical request for presigned URLs.
    init(
        method: String,
        url: URL,
        headers: [String: String],
        signedHeaderNames: [String],
        hashedPayload: String
    ) {
        self.method = method

        let path = url.path
        self.canonicalURI = path.isEmpty ? "/" : Self.uriEncode(path, encodeSlash: false)
        self.canonicalQueryString = Self.canonicalQueryString(from: url)

        let sortedHeaderNames = signedHeaderNames.map { $0.lowercased() }.sorted()
        var headersDict: [String: String] = [:]

        for (key, value) in headers {
            headersDict[key.lowercased()] = value.trimmingCharacters(in: .whitespaces)
        }

        if headersDict["host"] == nil, let host = url.host {
            headersDict["host"] = host
        }

        var canonicalHeadersBuilder = ""
        for name in sortedHeaderNames {
            if let value = headersDict[name] {
                canonicalHeadersBuilder += "\(name):\(value)\n"
            }
        }

        self.canonicalHeaders = canonicalHeadersBuilder
        self.signedHeaders = sortedHeaderNames.joined(separator: ";")
        self.hashedPayload = hashedPayload
    }

    /// Computes SHA-256 hash and returns it as a lowercase hex string.
    static func sha256Hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// URI-encodes a string according to AWS requirements.
    static func uriEncode(_ string: String, encodeSlash: Bool) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        if !encodeSlash {
            allowed.insert("/")
        }

        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    /// Builds a canonical query string from a URL.
    private static func canonicalQueryString(from url: URL?) -> String {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return ""
        }

        let sortedItems = queryItems.sorted { $0.name < $1.name }

        return sortedItems
            .map { item in
                let name = uriEncode(item.name, encodeSlash: true)
                let value = uriEncode(item.value ?? "", encodeSlash: true)
                return "\(name)=\(value)"
            }
            .joined(separator: "&")
    }
}
