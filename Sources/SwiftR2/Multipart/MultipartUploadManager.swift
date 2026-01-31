import Foundation

/// Manages multipart uploads with parallel part uploading.
///
/// `MultipartUploadManager` handles the complexity of splitting large files
/// into parts and uploading them in parallel with automatic retries.
///
/// ```swift
/// let manager = MultipartUploadManager(client: client)
///
/// let result = try await manager.upload(
///     bucket: "my-bucket",
///     key: "large-file.zip",
///     fileURL: localFileURL
/// ) { progress in
///     print("Progress: \(progress.percentCompleted ?? 0)%")
/// }
/// ```
///
/// ## Resumable Uploads
///
/// Save the ``ResumableUploadState`` to resume interrupted uploads:
///
/// ```swift
/// // Resume a previously started upload
/// let result = try await manager.resume(
///     state: savedState,
///     source: FileUploadSource(fileURL: fileURL)
/// )
/// ```
public actor MultipartUploadManager {
    private let client: R2Client
    private let configuration: MultipartUploadConfiguration

    /// Creates a multipart upload manager.
    ///
    /// - Parameters:
    ///   - client: The R2 client to use for API calls.
    ///   - configuration: The upload configuration. Defaults to ``MultipartUploadConfiguration/default``.
    public init(
        client: R2Client,
        configuration: MultipartUploadConfiguration = .default
    ) {
        self.client = client
        self.configuration = configuration
    }

    /// Uploads a file using multipart upload.
    ///
    /// Automatically splits the file into parts based on the configuration
    /// and uploads them in parallel with automatic retries.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - fileURL: The local file URL to upload.
    ///   - contentType: The MIME type. If `nil`, inferred from file extension.
    ///   - metadata: Custom metadata to store with the object.
    ///   - progress: Optional handler for progress updates.
    /// - Returns: The upload result containing the ETag.
    /// - Throws: ``R2Error/multipartUploadError(message:)`` if the upload fails.
    public func upload(
        bucket: String,
        key: String,
        fileURL: URL,
        contentType: String? = nil,
        metadata: [String: String] = [:],
        progress: R2ProgressHandler? = nil
    ) async throws -> R2PutObjectResult {
        let source = try FileUploadSource(fileURL: fileURL, contentType: contentType)
        return try await upload(
            bucket: bucket,
            key: key,
            source: source,
            metadata: metadata,
            progress: progress
        )
    }

    /// Uploads data from a source using multipart upload.
    ///
    /// Use this for custom data sources that implement ``R2UploadSource``.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - source: The upload source providing the data.
    ///   - metadata: Custom metadata to store with the object.
    ///   - progress: Optional handler for progress updates.
    /// - Returns: The upload result containing the ETag.
    /// - Throws: ``R2Error/multipartUploadError(message:)`` if the upload fails.
    public func upload(
        bucket: String,
        key: String,
        source: some R2UploadSource,
        metadata: [String: String] = [:],
        progress: R2ProgressHandler? = nil
    ) async throws -> R2PutObjectResult {
        // Initiate multipart upload
        let createResult = try await client.createMultipartUpload(
            bucket: bucket,
            key: key,
            contentType: source.contentType,
            metadata: metadata
        )

        let state = ResumableUploadState(
            bucket: bucket,
            key: key,
            uploadId: createResult.uploadId,
            partSize: configuration.partSize,
            totalSize: source.contentLength,
            completedParts: []
        )

        do {
            return try await uploadParts(
                state: state,
                source: source,
                progress: progress
            )
        } catch {
            // Try to abort on failure
            try? await client.abortMultipartUpload(
                bucket: bucket,
                key: key,
                uploadId: createResult.uploadId
            )
            throw error
        }
    }

    /// Resumes a previously started multipart upload.
    ///
    /// Use this to continue an upload that was interrupted. The source must
    /// provide data from the beginning; already-uploaded parts will be skipped.
    ///
    /// - Parameters:
    ///   - state: The saved upload state from a previous upload attempt.
    ///   - source: The upload source (must provide complete data).
    ///   - progress: Optional handler for progress updates.
    /// - Returns: The upload result containing the ETag.
    /// - Throws: ``R2Error/multipartUploadError(message:)`` if resumption fails.
    public func resume(
        state: ResumableUploadState,
        source: some R2UploadSource,
        progress: R2ProgressHandler? = nil
    ) async throws -> R2PutObjectResult {
        try await uploadParts(
            state: state,
            source: source,
            progress: progress
        )
    }

    /// Aborts a multipart upload and cleans up uploaded parts.
    ///
    /// Call this when you want to cancel an in-progress upload and free
    /// storage used by uploaded parts.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - uploadId: The upload ID to abort.
    /// - Throws: ``R2Error/multipartUploadError(message:)`` if abort fails.
    public func abort(
        bucket: String,
        key: String,
        uploadId: String
    ) async throws {
        try await client.abortMultipartUpload(
            bucket: bucket,
            key: key,
            uploadId: uploadId
        )
    }

    // MARK: - Private

    private func uploadParts(
        state: ResumableUploadState,
        source: some R2UploadSource,
        progress: R2ProgressHandler?
    ) async throws -> R2PutObjectResult {
        var completedParts = state.completedParts
        let completedPartNumbers = Set(completedParts.map(\.partNumber))
        var partNumber = 1
        var bytesUploaded: Int64 = state.bytesUploaded

        // Report initial progress
        progress?(R2Progress(completedBytes: bytesUploaded, totalBytes: state.totalSize))

        // Collect all parts first
        var parts: [(Int, Data)] = []
        var currentPart = Data()

        for try await chunk in source.chunks() {
            currentPart.append(chunk)

            while currentPart.count >= configuration.partSize {
                let partData = currentPart.prefix(configuration.partSize)
                parts.append((partNumber, Data(partData)))
                currentPart = Data(currentPart.dropFirst(configuration.partSize))
                partNumber += 1
            }
        }

        // Don't forget the last part
        if !currentPart.isEmpty {
            parts.append((partNumber, currentPart))
        }

        // Filter out already completed parts
        let partsToUpload = parts.filter { !completedPartNumbers.contains($0.0) }

        // Upload parts with concurrency limit
        try await withThrowingTaskGroup(of: R2CompletedPart.self) { group in
            var runningTasks = 0
            var partIndex = 0

            while partIndex < partsToUpload.count || runningTasks > 0 {
                // Add tasks up to concurrency limit
                while runningTasks < configuration.maxConcurrentUploads && partIndex < partsToUpload.count {
                    let (num, data) = partsToUpload[partIndex]
                    partIndex += 1
                    runningTasks += 1

                    group.addTask {
                        try await self.uploadPartWithRetry(
                            bucket: state.bucket,
                            key: state.key,
                            uploadId: state.uploadId,
                            partNumber: num,
                            data: data
                        )
                    }
                }

                // Wait for a task to complete
                if runningTasks > 0 {
                    let completedPart = try await group.next()!
                    runningTasks -= 1
                    completedParts.append(completedPart)
                    bytesUploaded += Int64(configuration.partSize)
                    progress?(R2Progress(completedBytes: bytesUploaded, totalBytes: state.totalSize))
                }
            }
        }

        // Complete the multipart upload
        let result = try await client.completeMultipartUpload(
            bucket: state.bucket,
            key: state.key,
            uploadId: state.uploadId,
            parts: completedParts
        )

        return R2PutObjectResult(etag: result.etag)
    }

    private func uploadPartWithRetry(
        bucket: String,
        key: String,
        uploadId: String,
        partNumber: Int,
        data: Data
    ) async throws -> R2CompletedPart {
        var lastError: Error?

        for attempt in 0...configuration.maxRetryAttempts {
            do {
                let result = try await client.uploadPart(
                    bucket: bucket,
                    key: key,
                    uploadId: uploadId,
                    partNumber: partNumber,
                    body: data
                )
                return R2CompletedPart(partNumber: partNumber, etag: result.etag)
            } catch {
                lastError = error

                if !configuration.retryFailedParts || attempt == configuration.maxRetryAttempts {
                    throw error
                }

                // Exponential backoff
                let delay = Double(1 << attempt) * 0.5
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? R2Error.multipartUploadError(message: "Upload failed after retries")
    }
}
