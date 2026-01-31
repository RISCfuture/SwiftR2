import Foundation

extension R2Client {
    /// Uploads a string to R2.
    ///
    /// The string is encoded as UTF-8 before uploading.
    ///
    /// ```swift
    /// try await client.put("Hello, World!", bucket: "bucket", key: "greeting.txt")
    /// ```
    ///
    /// - Parameters:
    ///   - string: The string to upload.
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - contentType: The MIME type. Defaults to `"text/plain; charset=utf-8"`.
    ///   - metadata: Custom metadata to store with the object.
    /// - Returns: The upload result containing the ETag.
    /// - Throws: ``R2Error/invalidRequest(message:)`` if the string cannot be encoded.
    @discardableResult
    public func put(
        _ string: String,
        bucket: String,
        key: String,
        contentType: String = "text/plain; charset=utf-8",
        metadata: [String: String] = [:]
    ) async throws -> R2PutObjectResult {
        guard let data = string.data(using: .utf8) else {
            throw R2Error.invalidRequest(message: "Failed to encode string as UTF-8")
        }
        return try await putObject(
            bucket: bucket,
            key: key,
            body: data,
            contentType: contentType,
            metadata: metadata
        )
    }

    /// Downloads an object as a string.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - encoding: The string encoding to use. Defaults to `.utf8`.
    /// - Returns: The object contents decoded as a string.
    /// - Throws: ``R2Error/notFound(bucket:key:)`` if the object doesn't exist.
    ///   ``R2Error/invalidResponse(message:)`` if the data cannot be decoded.
    public func getString(
        bucket: String,
        key: String,
        encoding: String.Encoding = .utf8
    ) async throws -> String {
        let result = try await getObject(bucket: bucket, key: key)
        guard let string = String(data: result.data, encoding: encoding) else {
            throw R2Error.invalidResponse(message: "Failed to decode response as string")
        }
        return string
    }
}
