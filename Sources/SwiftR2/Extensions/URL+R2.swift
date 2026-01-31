import Foundation

extension R2Client {
    /// Uploads a file to R2.
    ///
    /// For small files (under 5MB), uses a single PUT request.
    /// For larger files, automatically uses multipart upload.
    ///
    /// ```swift
    /// try await client.putFile(
    ///     from: localFileURL,
    ///     bucket: "bucket",
    ///     key: "documents/report.pdf"
    /// ) { progress in
    ///     print("Progress: \(progress.percentCompleted ?? 0)%")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - fileURL: The local file URL to upload.
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - contentType: The MIME type. If `nil`, inferred from file extension.
    ///   - metadata: Custom metadata to store with the object.
    ///   - progress: Optional handler for progress updates.
    /// - Returns: The upload result containing the ETag.
    /// - Throws: An error if the file cannot be read or the upload fails.
    @discardableResult
    public func putFile(
        from fileURL: URL,
        bucket: String,
        key: String,
        contentType: String? = nil,
        metadata: [String: String] = [:],
        progress: R2ProgressHandler? = nil
    ) async throws -> R2PutObjectResult {
        let source = try FileUploadSource(fileURL: fileURL, contentType: contentType)

        // For small files, use single PUT
        if let size = source.contentLength, size < MultipartUploadConfiguration.minimumPartSize {
            let data = try Data(contentsOf: fileURL)
            return try await putObject(
                bucket: bucket,
                key: key,
                body: data,
                contentType: source.contentType ?? "application/octet-stream",
                metadata: metadata
            )
        }

        // For larger files, use multipart upload
        let manager = MultipartUploadManager(client: self)
        return try await manager.upload(
            bucket: bucket,
            key: key,
            fileURL: fileURL,
            contentType: contentType,
            metadata: metadata,
            progress: progress
        )
    }

    /// Downloads an object to a file.
    ///
    /// Downloads the object in chunks and writes directly to disk,
    /// minimizing memory usage for large files.
    ///
    /// ```swift
    /// let metadata = try await client.getFile(
    ///     bucket: "bucket",
    ///     key: "large-file.zip",
    ///     to: localDestinationURL
    /// ) { progress in
    ///     print("Downloaded: \(progress.completedBytes) bytes")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - destinationURL: The local file URL to write to.
    ///   - progress: Optional handler for progress updates.
    /// - Returns: The object metadata.
    /// - Throws: ``R2Error/notFound(bucket:key:)`` if the object doesn't exist.
    @discardableResult
    public func getFile(
        bucket: String,
        key: String,
        to destinationURL: URL,
        progress: R2ProgressHandler? = nil
    ) async throws -> R2ObjectMetadata {
        let stream = try await getObjectStream(bucket: bucket, key: key)

        // Create or truncate the destination file
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destinationURL)

        defer {
            try? handle.close()
        }

        var bytesWritten: Int64 = 0

        for try await chunk in stream {
            try handle.write(contentsOf: chunk)
            bytesWritten += Int64(chunk.count)
            progress?(R2Progress(completedBytes: bytesWritten, totalBytes: stream.contentLength))
        }

        return R2ObjectMetadata(
            key: key,
            size: bytesWritten,
            etag: stream.etag ?? "",
            lastModified: stream.lastModified ?? Date(),
            contentType: stream.contentType,
            metadata: stream.metadata
        )
    }
}
