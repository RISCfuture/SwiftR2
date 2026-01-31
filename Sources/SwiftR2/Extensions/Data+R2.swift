import Foundation

extension R2Client {
    /// Uploads binary data to R2.
    ///
    /// A convenience method for uploading `Data` directly.
    ///
    /// ```swift
    /// let imageData = try Data(contentsOf: imageURL)
    /// try await client.put(imageData, bucket: "bucket", key: "image.jpg", contentType: "image/jpeg")
    /// ```
    ///
    /// - Parameters:
    ///   - data: The data to upload.
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - contentType: The MIME type. Defaults to `"application/octet-stream"`.
    ///   - metadata: Custom metadata to store with the object.
    /// - Returns: The upload result containing the ETag.
    /// - Throws: ``R2Error`` if the upload fails.
    @discardableResult
    public func put(
        _ data: Data,
        bucket: String,
        key: String,
        contentType: String = "application/octet-stream",
        metadata: [String: String] = [:]
    ) async throws -> R2PutObjectResult {
        try await putObject(
            bucket: bucket,
            key: key,
            body: data,
            contentType: contentType,
            metadata: metadata
        )
    }

    /// Downloads an object as `Data`.
    ///
    /// A convenience method that returns just the data without metadata.
    /// Use ``getWithMetadata(bucket:key:)`` to also retrieve metadata.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    /// - Returns: The complete object data.
    /// - Throws: ``R2Error/notFound(bucket:key:)`` if the object doesn't exist.
    public func get(bucket: String, key: String) async throws -> Data {
        let result = try await getObject(bucket: bucket, key: key)
        return result.data
    }

    /// Downloads an object with its metadata.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    /// - Returns: The result containing data and metadata.
    /// - Throws: ``R2Error/notFound(bucket:key:)`` if the object doesn't exist.
    public func getWithMetadata(
        bucket: String,
        key: String
    ) async throws -> R2GetObjectResult {
        try await getObject(bucket: bucket, key: key)
    }
}
