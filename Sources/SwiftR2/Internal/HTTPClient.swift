import Foundation

/// Internal HTTP client wrapper for URLSession.
actor HTTPClient {
    private let session: URLSession
    private let signer: AWSSignatureV4
    private let baseURL: URL
    private let timeoutInterval: TimeInterval

    init(
        configuration: R2ClientConfiguration,
        credentials: R2Credentials
    ) {
        self.session = URLSession(configuration: configuration.urlSessionConfiguration)
        self.signer = AWSSignatureV4(
            credentials: credentials,
            region: R2ClientConfiguration.region,
            service: R2ClientConfiguration.service
        )
        self.baseURL = configuration.endpoint
        self.timeoutInterval = configuration.timeoutInterval
    }

    /// Performs a request and returns the response data.
    func perform(
        method: String,
        bucket: String,
        key: String? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let request = try buildRequest(
            method: method,
            bucket: bucket,
            key: key,
            queryItems: queryItems,
            headers: headers,
            body: body
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw R2Error.invalidResponse(message: "Invalid response type")
        }

        try validateResponse(httpResponse, data: data, bucket: bucket, key: key)

        return (data, httpResponse)
    }

    /// Performs a request and returns a stream of data.
    func performStream(
        method: String,
        bucket: String,
        key: String? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:]
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let request = try buildRequest(
            method: method,
            bucket: bucket,
            key: key,
            queryItems: queryItems,
            headers: headers,
            body: nil
        )

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw R2Error.invalidResponse(message: "Invalid response type")
        }

        // For streaming, we can't read the body for error parsing yet
        // We'll check for errors before streaming starts
        if httpResponse.statusCode >= 400 {
            // Collect the error body
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            try validateResponse(httpResponse, data: errorData, bucket: bucket, key: key)
        }

        return (bytes, httpResponse)
    }

    /// Builds a signed request.
    private func buildRequest(
        method: String,
        bucket: String,
        key: String? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        body: Data? = nil
    ) throws -> URLRequest {
        // Build URL
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!

        var path = "/\(bucket)"
        if let key {
            path += "/\(key)"
        }
        components.path = path

        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw R2Error.invalidRequest(message: "Failed to build URL")
        }

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = body
            if request.value(forHTTPHeaderField: "Content-Length") == nil {
                request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
            }
        }

        // Sign the request
        return signer.sign(request: request, payload: body)
    }

    /// Validates an HTTP response and throws appropriate errors.
    private func validateResponse(
        _ response: HTTPURLResponse,
        data: Data,
        bucket: String,
        key: String?
    ) throws {
        let statusCode = response.statusCode

        guard statusCode >= 200 && statusCode < 300 else {
            // Parse error response
            let serviceError = R2XMLParser.parseError(data: data, statusCode: statusCode)

            switch serviceError.code {
            case "NoSuchKey":
                throw R2Error.notFound(bucket: bucket, key: key)
            case "NoSuchBucket":
                throw R2Error.bucketNotFound(bucket: bucket)
            case "AccessDenied":
                throw R2Error.accessDenied(message: serviceError.message)
            case "InvalidAccessKeyId", "SignatureDoesNotMatch":
                throw R2Error.missingCredentials(serviceError.message)
            case "PreconditionFailed":
                throw R2Error.preconditionFailed(message: serviceError.message)
            case "SlowDown", "ServiceUnavailable":
                let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { TimeInterval($0) }
                throw R2Error.rateLimited(retryAfter: retryAfter)
            default:
                throw R2Error.serviceError(serviceError)
            }
        }
    }

    /// Generates a presigned URL.
    func presignedURL(
        method: String,
        bucket: String,
        key: String,
        expiration: TimeInterval,
        contentType: String? = nil
    ) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/\(bucket)/\(key)"

        var headers: [String: String] = [:]
        if let contentType {
            headers["content-type"] = contentType
        }

        return signer.presignedURL(
            url: components.url!,
            method: method,
            expiration: expiration,
            additionalHeaders: headers
        )
    }
}
