import Foundation

/// Metadata for an R2 object.
///
/// Contains information about an object without the object body itself.
/// Retrieved via ``R2Client/headObject(bucket:key:)`` or included with
/// ``R2GetObjectResult``.
public struct R2ObjectMetadata: Sendable, Equatable {
    /// The object key (path within the bucket).
    public let key: String

    /// The size of the object in bytes.
    public let size: Int64

    /// The entity tag (ETag) of the object.
    ///
    /// For objects uploaded in a single PUT, this is the MD5 hash of the content.
    /// For multipart uploads, this is a computed hash with a part count suffix.
    public let etag: String

    /// The date and time the object was last modified.
    public let lastModified: Date

    /// The storage class of the object.
    public let storageClass: StorageClass

    /// The MIME type of the object content.
    public let contentType: String?

    /// Custom metadata associated with the object.
    ///
    /// Keys are returned without the `x-amz-meta-` prefix.
    public let metadata: [String: String]

    /// Creates new object metadata.
    ///
    /// - Parameters:
    ///   - key: The object key.
    ///   - size: The size in bytes.
    ///   - etag: The entity tag.
    ///   - lastModified: The last modified date.
    ///   - storageClass: The storage class.
    ///   - contentType: The content type.
    ///   - metadata: Custom metadata.
    public init(
        key: String,
        size: Int64,
        etag: String,
        lastModified: Date,
        storageClass: StorageClass = .standard,
        contentType: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.key = key
        self.size = size
        self.etag = etag
        self.lastModified = lastModified
        self.storageClass = storageClass
        self.contentType = contentType
        self.metadata = metadata
    }
}

/// Result of a GetObject operation.
///
/// Contains the downloaded object data along with its metadata.
/// Returned by ``R2Client/getObject(bucket:key:)`` and
/// ``R2Client/getWithMetadata(bucket:key:)``.
public struct R2GetObjectResult: Sendable {
    /// The complete object data.
    public let data: Data

    /// The object metadata including size, ETag, and content type.
    public let metadata: R2ObjectMetadata

    /// The MIME type of the object content.
    public var contentType: String? { metadata.contentType }

    /// The size of the object in bytes.
    public var size: Int64 { metadata.size }

    /// The entity tag (ETag) of the object.
    public var etag: String { metadata.etag }

    /// Creates a new get object result.
    ///
    /// - Parameters:
    ///   - data: The object data.
    ///   - metadata: The object metadata.
    public init(data: Data, metadata: R2ObjectMetadata) {
        self.data = data
        self.metadata = metadata
    }
}

/// Result of a PutObject operation.
///
/// Returned by ``R2Client/putObject(bucket:key:body:contentType:metadata:)``
/// and related upload methods.
public struct R2PutObjectResult: Sendable, Equatable {
    /// The entity tag (ETag) of the uploaded object.
    ///
    /// Can be used for conditional requests or verification.
    public let etag: String

    /// The version ID of the object, if versioning is enabled on the bucket.
    public let versionId: String?

    /// Creates a new put object result.
    ///
    /// - Parameters:
    ///   - etag: The ETag of the uploaded object.
    ///   - versionId: The version ID, if applicable.
    public init(etag: String, versionId: String? = nil) {
        self.etag = etag
        self.versionId = versionId
    }
}

/// Result of a CopyObject operation.
///
/// Returned by ``R2Client/copyObject(sourceBucket:sourceKey:destBucket:destKey:)``.
public struct R2CopyObjectResult: Sendable, Equatable {
    /// The entity tag (ETag) of the copied object.
    public let etag: String

    /// The date and time the copy was created.
    public let lastModified: Date

    /// Creates a new copy object result.
    ///
    /// - Parameters:
    ///   - etag: The ETag of the copied object.
    ///   - lastModified: The last modified date.
    public init(etag: String, lastModified: Date) {
        self.etag = etag
        self.lastModified = lastModified
    }
}

/// Result of a HeadObject operation.
///
/// An alias for ``R2ObjectMetadata`` for semantic clarity.
public typealias R2HeadObjectResult = R2ObjectMetadata
