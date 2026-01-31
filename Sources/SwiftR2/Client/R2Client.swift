import Foundation

/// A client for interacting with Cloudflare R2 object storage.
///
/// `R2Client` provides a complete interface for performing S3-compatible operations
/// on Cloudflare R2 buckets, including uploading, downloading, listing, and deleting objects.
///
/// The client is implemented as an actor to ensure thread-safe access to its internal state.
///
/// ## Creating a Client
///
/// The simplest way to create a client is with static credentials:
///
/// ```swift
/// let client = R2Client(
///     accountId: "your-account-id",
///     accessKeyId: "your-access-key-id",
///     secretAccessKey: "your-secret-access-key"
/// )
/// ```
///
/// For more control, use ``R2ClientConfiguration``:
///
/// ```swift
/// let config = R2ClientConfiguration(
///     accountId: "your-account-id",
///     credentialsProvider: EnvironmentCredentialsProvider(),
///     timeoutInterval: 120
/// )
/// let client = R2Client(configuration: config)
/// ```
///
/// ## Basic Operations
///
/// ```swift
/// // Upload a string
/// try await client.put("Hello, R2!", bucket: "my-bucket", key: "hello.txt")
///
/// // Download as data
/// let data = try await client.get(bucket: "my-bucket", key: "hello.txt")
///
/// // List objects
/// let result = try await client.listObjects(bucket: "my-bucket", prefix: "files/")
///
/// // Delete an object
/// try await client.deleteObject(bucket: "my-bucket", key: "hello.txt")
/// ```
public actor R2Client {
    private let configuration: R2ClientConfiguration
    private var httpClient: HTTPClient?
    private var credentials: R2Credentials?

    /// Creates a new R2 client with the specified configuration.
    ///
    /// - Parameter configuration: The client configuration containing account ID,
    ///   credentials provider, and other settings.
    public init(configuration: R2ClientConfiguration) {
        self.configuration = configuration
    }

    /// Creates a new R2 client with static credentials.
    ///
    /// This is a convenience initializer for quickly creating a client with
    /// hardcoded credentials. For production use, consider using
    /// ``init(configuration:)`` with an ``EnvironmentCredentialsProvider``
    /// or ``ChainedCredentialsProvider``.
    ///
    /// - Parameters:
    ///   - accountId: The Cloudflare account ID.
    ///   - accessKeyId: The R2 access key ID.
    ///   - secretAccessKey: The R2 secret access key.
    public init(
        accountId: String,
        accessKeyId: String,
        secretAccessKey: String
    ) {
        self.configuration = R2ClientConfiguration(
            accountId: accountId,
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey
        )
    }

    // MARK: - Object Operations

    /// Gets an object from R2.
    ///
    /// Downloads the complete object into memory. For large objects, consider using
    /// ``getObjectStream(bucket:key:)`` to process data in chunks.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key (path within the bucket).
    /// - Returns: The object data and metadata wrapped in ``R2GetObjectResult``.
    /// - Throws: ``R2Error/notFound(bucket:key:)`` if the object doesn't exist.
    ///   ``R2Error/accessDenied(message:)`` if access is denied.
    public func getObject(bucket: String, key: String) async throws -> R2GetObjectResult {
        let client = try await getHTTPClient()
        let (data, response) = try await client.perform(
            method: "GET",
            bucket: bucket,
            key: key
        )

        let metadata = extractMetadata(from: response, key: key, size: Int64(data.count))
        return R2GetObjectResult(data: data, metadata: metadata)
    }

    /// Gets an object as a stream.
    ///
    /// Returns an ``R2DownloadStream`` that yields data chunks as they arrive.
    /// This is more memory-efficient than ``getObject(bucket:key:)`` for large files.
    ///
    /// ```swift
    /// let stream = try await client.getObjectStream(bucket: "my-bucket", key: "large-file.zip")
    /// for try await chunk in stream {
    ///     // Process each chunk
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key (path within the bucket).
    /// - Returns: An async sequence of data chunks with object metadata.
    /// - Throws: ``R2Error/notFound(bucket:key:)`` if the object doesn't exist.
    public func getObjectStream(bucket: String, key: String) async throws -> R2DownloadStream {
        let client = try await getHTTPClient()
        let (bytes, response) = try await client.performStream(
            method: "GET",
            bucket: bucket,
            key: key
        )

        return R2DownloadStream(bytes: bytes, response: response)
    }

    /// Uploads an object to R2.
    ///
    /// Uploads the provided data as a single object. For files larger than 5MB,
    /// consider using ``putFile(from:bucket:key:contentType:metadata:progress:)``
    /// which automatically uses multipart upload.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key (path within the bucket).
    ///   - body: The object data to upload.
    ///   - contentType: The MIME type of the content. Defaults to `"application/octet-stream"`.
    ///   - metadata: Custom metadata to store with the object. Keys are automatically
    ///     prefixed with `x-amz-meta-`.
    /// - Returns: The upload result containing the ETag and optional version ID.
    /// - Throws: ``R2Error/accessDenied(message:)`` if access is denied.
    ///   ``R2Error/networkError(message:)`` on network failures.
    @discardableResult
    public func putObject(
        bucket: String,
        key: String,
        body: Data,
        contentType: String = "application/octet-stream",
        metadata: [String: String] = [:]
    ) async throws -> R2PutObjectResult {
        let client = try await getHTTPClient()

        var headers: [String: String] = [
            "Content-Type": contentType
        ]

        for (metaKey, metaValue) in metadata {
            headers["x-amz-meta-\(metaKey)"] = metaValue
        }

        let (_, response) = try await client.perform(
            method: "PUT",
            bucket: bucket,
            key: key,
            headers: headers,
            body: body
        )

        let etag = response.value(forHTTPHeaderField: "ETag")?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
        let versionId = response.value(forHTTPHeaderField: "x-amz-version-id")

        return R2PutObjectResult(etag: etag, versionId: versionId)
    }

    /// Uploads an object from a streaming source.
    ///
    /// Collects data from the provided ``R2UploadSource`` and uploads it as a single object.
    /// The content type is automatically set from the source if available.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key (path within the bucket).
    ///   - source: The upload source providing the data stream.
    ///   - metadata: Custom metadata to store with the object.
    /// - Returns: The upload result containing the ETag and optional version ID.
    /// - Throws: ``R2Error`` if the upload fails.
    @discardableResult
    public func putObjectStream(
        bucket: String,
        key: String,
        source: some R2UploadSource,
        metadata: [String: String] = [:]
    ) async throws -> R2PutObjectResult {
        // Collect all data from the source
        var allData = Data()
        for try await chunk in source.chunks() {
            allData.append(chunk)
        }

        return try await putObject(
            bucket: bucket,
            key: key,
            body: allData,
            contentType: source.contentType ?? "application/octet-stream",
            metadata: metadata
        )
    }

    /// Deletes an object from R2.
    ///
    /// Permanently removes the specified object from the bucket.
    /// This operation succeeds even if the object doesn't exist.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key (path within the bucket).
    /// - Throws: ``R2Error/accessDenied(message:)`` if access is denied.
    public func deleteObject(bucket: String, key: String) async throws {
        let client = try await getHTTPClient()
        _ = try await client.perform(
            method: "DELETE",
            bucket: bucket,
            key: key
        )
    }

    /// Deletes multiple objects from R2 in a single request.
    ///
    /// More efficient than calling ``deleteObject(bucket:key:)`` multiple times
    /// when deleting several objects.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - keys: The object keys to delete (up to 1000).
    /// - Returns: The deletion result containing successfully deleted objects and any errors.
    /// - Throws: ``R2Error`` if the bulk delete request fails entirely.
    public func deleteObjects(
        bucket: String,
        keys: [String]
    ) async throws -> R2DeleteObjectsResult {
        let client = try await getHTTPClient()
        let body = R2XMLBuilder.buildDeleteObjects(keys: keys)

        let (data, _) = try await client.perform(
            method: "POST",
            bucket: bucket,
            queryItems: [URLQueryItem(name: "delete", value: nil)],
            headers: ["Content-Type": "application/xml"],
            body: body
        )

        return try R2XMLParser.parseDeleteObjects(data: data)
    }

    /// Gets object metadata without downloading the object body.
    ///
    /// Use this to check if an object exists or retrieve its metadata
    /// without incurring the bandwidth cost of downloading the content.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key (path within the bucket).
    /// - Returns: The object metadata including size, ETag, content type, and custom metadata.
    /// - Throws: ``R2Error/notFound(bucket:key:)`` if the object doesn't exist.
    public func headObject(bucket: String, key: String) async throws -> R2ObjectMetadata {
        let client = try await getHTTPClient()
        let (_, response) = try await client.perform(
            method: "HEAD",
            bucket: bucket,
            key: key
        )

        let contentLength = response.value(forHTTPHeaderField: "Content-Length")
            .flatMap { Int64($0) } ?? 0

        return extractMetadata(from: response, key: key, size: contentLength)
    }

    /// Lists objects in a bucket.
    ///
    /// Returns up to `maxKeys` objects matching the specified criteria.
    /// Use `prefix` to filter objects and `delimiter` to group results.
    ///
    /// ```swift
    /// // List all objects with a prefix
    /// let result = try await client.listObjects(bucket: "my-bucket", prefix: "photos/")
    ///
    /// // Paginate through results
    /// var token: String? = nil
    /// repeat {
    ///     let result = try await client.listObjects(
    ///         bucket: "my-bucket",
    ///         continuationToken: token
    ///     )
    ///     // Process result.objects
    ///     token = result.nextContinuationToken
    /// } while token != nil
    /// ```
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - prefix: Filter results to keys starting with this prefix.
    ///   - delimiter: Character used to group keys into common prefixes.
    ///     Use `"/"` to simulate a folder hierarchy.
    ///   - maxKeys: Maximum number of keys to return. Defaults to 1000 (maximum allowed).
    ///   - continuationToken: Token from a previous response to fetch the next page.
    /// - Returns: The list result containing objects, common prefixes, and pagination info.
    /// - Throws: ``R2Error/bucketNotFound(bucket:)`` if the bucket doesn't exist.
    public func listObjects(
        bucket: String,
        prefix: String? = nil,
        delimiter: String? = nil,
        maxKeys: Int = 1000,
        continuationToken: String? = nil
    ) async throws -> R2ListObjectsResult {
        let client = try await getHTTPClient()

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "list-type", value: "2"),
            URLQueryItem(name: "max-keys", value: String(maxKeys))
        ]

        if let prefix {
            queryItems.append(URLQueryItem(name: "prefix", value: prefix))
        }

        if let delimiter {
            queryItems.append(URLQueryItem(name: "delimiter", value: delimiter))
        }

        if let token = continuationToken {
            queryItems.append(URLQueryItem(name: "continuation-token", value: token))
        }

        let (data, _) = try await client.perform(
            method: "GET",
            bucket: bucket,
            queryItems: queryItems
        )

        return try R2XMLParser.parseListObjectsV2(data: data)
    }

    /// Copies an object within R2.
    ///
    /// Creates a copy of an object, optionally in a different bucket.
    /// This is a server-side copy that doesn't require downloading and re-uploading.
    ///
    /// - Parameters:
    ///   - sourceBucket: The source bucket name.
    ///   - sourceKey: The source object key.
    ///   - destBucket: The destination bucket name.
    ///   - destKey: The destination object key.
    /// - Returns: The copy result containing the new ETag and last modified date.
    /// - Throws: ``R2Error/notFound(bucket:key:)`` if the source object doesn't exist.
    public func copyObject(
        sourceBucket: String,
        sourceKey: String,
        destBucket: String,
        destKey: String
    ) async throws -> R2CopyObjectResult {
        let client = try await getHTTPClient()
        let copySource = "/\(sourceBucket)/\(sourceKey)"

        let (data, _) = try await client.perform(
            method: "PUT",
            bucket: destBucket,
            key: destKey,
            headers: ["x-amz-copy-source": copySource]
        )

        return try R2XMLParser.parseCopyObject(data: data)
    }

    // MARK: - Multipart Upload

    /// Initiates a multipart upload.
    ///
    /// For most use cases, prefer ``MultipartUploadManager`` which handles
    /// the complexity of splitting files and uploading parts concurrently.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - contentType: The MIME type of the content.
    ///   - metadata: Custom metadata to store with the object.
    /// - Returns: The result containing the upload ID needed for subsequent operations.
    /// - Throws: ``R2Error`` if the upload initiation fails.
    public func createMultipartUpload(
        bucket: String,
        key: String,
        contentType: String? = nil,
        metadata: [String: String] = [:]
    ) async throws -> R2CreateMultipartUploadResult {
        let client = try await getHTTPClient()

        var headers: [String: String] = [:]
        if let contentType {
            headers["Content-Type"] = contentType
        }

        for (metaKey, metaValue) in metadata {
            headers["x-amz-meta-\(metaKey)"] = metaValue
        }

        let (data, _) = try await client.perform(
            method: "POST",
            bucket: bucket,
            key: key,
            queryItems: [URLQueryItem(name: "uploads", value: nil)],
            headers: headers
        )

        return try R2XMLParser.parseCreateMultipartUpload(data: data)
    }

    /// Uploads a part in a multipart upload.
    ///
    /// Each part must be at least 5MB except for the last part.
    /// Part numbers must be between 1 and 10000.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - uploadId: The upload ID from ``createMultipartUpload(bucket:key:contentType:metadata:)``.
    ///   - partNumber: The part number (1-10000). Parts can be uploaded in any order.
    ///   - body: The part data (minimum 5MB except for last part).
    /// - Returns: The result containing the part number and ETag.
    /// - Throws: ``R2Error/multipartUploadError(message:)`` if the upload fails.
    public func uploadPart(
        bucket: String,
        key: String,
        uploadId: String,
        partNumber: Int,
        body: Data
    ) async throws -> R2UploadPartResult {
        let client = try await getHTTPClient()

        let queryItems = [
            URLQueryItem(name: "uploadId", value: uploadId),
            URLQueryItem(name: "partNumber", value: String(partNumber))
        ]

        let (_, response) = try await client.perform(
            method: "PUT",
            bucket: bucket,
            key: key,
            queryItems: queryItems,
            body: body
        )

        let etag = response.value(forHTTPHeaderField: "ETag")?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""

        return R2UploadPartResult(partNumber: partNumber, etag: etag)
    }

    /// Completes a multipart upload.
    ///
    /// Call this after all parts have been uploaded to assemble them into the final object.
    /// Parts must be provided in ascending order by part number.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - uploadId: The upload ID from ``createMultipartUpload(bucket:key:contentType:metadata:)``.
    ///   - parts: The completed parts with their ETags, in ascending part number order.
    /// - Returns: The result containing the final ETag and location.
    /// - Throws: ``R2Error/multipartUploadError(message:)`` if completion fails.
    public func completeMultipartUpload(
        bucket: String,
        key: String,
        uploadId: String,
        parts: [R2CompletedPart]
    ) async throws -> R2CompleteMultipartUploadResult {
        let client = try await getHTTPClient()
        let body = R2XMLBuilder.buildCompleteMultipartUpload(parts: parts)

        let (data, _) = try await client.perform(
            method: "POST",
            bucket: bucket,
            key: key,
            queryItems: [URLQueryItem(name: "uploadId", value: uploadId)],
            headers: ["Content-Type": "application/xml"],
            body: body
        )

        return try R2XMLParser.parseCompleteMultipartUpload(data: data)
    }

    /// Aborts a multipart upload.
    ///
    /// Cancels an in-progress multipart upload and frees any uploaded parts.
    /// Call this to clean up if you don't intend to complete the upload.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - uploadId: The upload ID from ``createMultipartUpload(bucket:key:contentType:metadata:)``.
    /// - Throws: ``R2Error/multipartUploadError(message:)`` if abort fails.
    public func abortMultipartUpload(
        bucket: String,
        key: String,
        uploadId: String
    ) async throws {
        let client = try await getHTTPClient()

        _ = try await client.perform(
            method: "DELETE",
            bucket: bucket,
            key: key,
            queryItems: [URLQueryItem(name: "uploadId", value: uploadId)]
        )
    }

    // MARK: - Presigned URLs

    /// Generates a presigned URL for downloading an object.
    ///
    /// Returns a URL that can be used to download the object without credentials.
    /// Useful for sharing temporary access to private objects.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - expiration: How long the URL should be valid in seconds. Defaults to 1 hour.
    ///     Maximum is 7 days (604800 seconds).
    /// - Returns: A presigned URL for GET requests.
    /// - Throws: ``R2Error/missingCredentials(_:)`` if credentials are unavailable.
    public func presignedGetURL(
        bucket: String,
        key: String,
        expiration: TimeInterval = 3600
    ) async throws -> URL {
        let client = try await getHTTPClient()
        return await client.presignedURL(
            method: "GET",
            bucket: bucket,
            key: key,
            expiration: expiration
        )
    }

    /// Generates a presigned URL for uploading an object.
    ///
    /// Returns a URL that can be used to upload an object without credentials.
    /// The uploader must use the specified content type when making the PUT request.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - contentType: The content type the uploader must use. Defaults to `"application/octet-stream"`.
    ///   - expiration: How long the URL should be valid in seconds. Defaults to 1 hour.
    /// - Returns: A presigned URL for PUT requests.
    /// - Throws: ``R2Error/missingCredentials(_:)`` if credentials are unavailable.
    public func presignedPutURL(
        bucket: String,
        key: String,
        contentType: String = "application/octet-stream",
        expiration: TimeInterval = 3600
    ) async throws -> URL {
        let client = try await getHTTPClient()
        return await client.presignedURL(
            method: "PUT",
            bucket: bucket,
            key: key,
            expiration: expiration,
            contentType: contentType
        )
    }

    // MARK: - Private

    private func getHTTPClient() async throws -> HTTPClient {
        if let client = httpClient {
            return client
        }

        let creds = try await configuration.credentialsProvider.credentials()
        let client = HTTPClient(configuration: configuration, credentials: creds)
        self.httpClient = client
        self.credentials = creds
        return client
    }

    private func extractMetadata(
        from response: HTTPURLResponse,
        key: String,
        size: Int64
    ) -> R2ObjectMetadata {
        let etag = response.value(forHTTPHeaderField: "ETag")?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""

        let lastModified: Date
        if let dateString = response.value(forHTTPHeaderField: "Last-Modified") {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            lastModified = formatter.date(from: dateString) ?? Date()
        } else {
            lastModified = Date()
        }

        let contentType = response.value(forHTTPHeaderField: "Content-Type")

        let storageClassString = response.value(forHTTPHeaderField: "x-amz-storage-class") ?? "STANDARD"
        let storageClass = StorageClass(rawValue: storageClassString) ?? .standard

        var customMetadata: [String: String] = [:]
        for (headerKey, value) in response.allHeaderFields {
            if let keyString = headerKey as? String,
               keyString.lowercased().hasPrefix("x-amz-meta-"),
               let valueString = value as? String {
                let metaKey = String(keyString.dropFirst("x-amz-meta-".count))
                customMetadata[metaKey] = valueString
            }
        }

        return R2ObjectMetadata(
            key: key,
            size: size,
            etag: etag,
            lastModified: lastModified,
            storageClass: storageClass,
            contentType: contentType,
            metadata: customMetadata
        )
    }
}
