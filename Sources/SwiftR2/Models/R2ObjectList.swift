import Foundation

/// An object entry in a list response.
///
/// Represents a single object returned by ``R2Client/listObjects(bucket:prefix:delimiter:maxKeys:continuationToken:)``.
/// Contains basic metadata; use ``R2Client/headObject(bucket:key:)`` for full metadata.
public struct R2ListObject: Sendable, Equatable {
    /// The object key (path within the bucket).
    public let key: String

    /// The size of the object in bytes.
    public let size: Int64

    /// The entity tag (ETag) of the object.
    public let etag: String

    /// The date and time the object was last modified.
    public let lastModified: Date

    /// The storage class of the object.
    public let storageClass: StorageClass

    /// Creates a new list object entry.
    ///
    /// - Parameters:
    ///   - key: The object key.
    ///   - size: The size in bytes.
    ///   - etag: The entity tag.
    ///   - lastModified: The last modified date.
    ///   - storageClass: The storage class.
    public init(
        key: String,
        size: Int64,
        etag: String,
        lastModified: Date,
        storageClass: StorageClass = .standard
    ) {
        self.key = key
        self.size = size
        self.etag = etag
        self.lastModified = lastModified
        self.storageClass = storageClass
    }
}

/// A common prefix in a list response.
///
/// When listing objects with a delimiter (typically `"/"`), objects with
/// a common prefix are grouped together. This simulates a folder hierarchy.
///
/// ```swift
/// let result = try await client.listObjects(bucket: "my-bucket", delimiter: "/")
/// for prefix in result.commonPrefixes {
///     print("Folder: \(prefix.prefix)")
/// }
/// ```
public struct R2CommonPrefix: Sendable, Equatable {
    /// The common prefix shared by grouped objects.
    public let prefix: String

    /// Creates a new common prefix.
    ///
    /// - Parameter prefix: The prefix string.
    public init(prefix: String) {
        self.prefix = prefix
    }
}

/// Result of a ListObjectsV2 operation.
///
/// Contains the objects matching the list criteria along with pagination information.
/// Returned by ``R2Client/listObjects(bucket:prefix:delimiter:maxKeys:continuationToken:)``.
///
/// ## Pagination
///
/// When ``isTruncated`` is `true`, use ``nextContinuationToken`` to fetch the next page:
///
/// ```swift
/// var token: String? = nil
/// repeat {
///     let result = try await client.listObjects(bucket: "bucket", continuationToken: token)
///     for object in result.objects {
///         print(object.key)
///     }
///     token = result.nextContinuationToken
/// } while token != nil
/// ```
public struct R2ListObjectsResult: Sendable, Equatable {
    /// The objects matching the list criteria.
    public let objects: [R2ListObject]

    /// The common prefixes when using a delimiter.
    ///
    /// See ``R2CommonPrefix`` for details on folder-like grouping.
    public let commonPrefixes: [R2CommonPrefix]

    /// Whether more results are available beyond this response.
    ///
    /// If `true`, use ``nextContinuationToken`` to fetch the next page.
    public let isTruncated: Bool

    /// The token to use for fetching the next page of results.
    ///
    /// Only present when ``isTruncated`` is `true`.
    public let nextContinuationToken: String?

    /// The prefix filter used in the request, if any.
    public let prefix: String?

    /// The delimiter used in the request, if any.
    public let delimiter: String?

    /// The maximum number of keys that were requested.
    public let maxKeys: Int

    /// The actual number of keys returned in this response.
    public let keyCount: Int

    /// Creates a new list objects result.
    ///
    /// - Parameters:
    ///   - objects: The objects in the list.
    ///   - commonPrefixes: The common prefixes.
    ///   - isTruncated: Whether more results are available.
    ///   - nextContinuationToken: Token for the next page.
    ///   - prefix: The prefix filter used.
    ///   - delimiter: The delimiter used.
    ///   - maxKeys: Maximum keys requested.
    ///   - keyCount: Actual keys returned.
    public init(
        objects: [R2ListObject],
        commonPrefixes: [R2CommonPrefix] = [],
        isTruncated: Bool,
        nextContinuationToken: String? = nil,
        prefix: String? = nil,
        delimiter: String? = nil,
        maxKeys: Int,
        keyCount: Int
    ) {
        self.objects = objects
        self.commonPrefixes = commonPrefixes
        self.isTruncated = isTruncated
        self.nextContinuationToken = nextContinuationToken
        self.prefix = prefix
        self.delimiter = delimiter
        self.maxKeys = maxKeys
        self.keyCount = keyCount
    }
}

/// Result of a DeleteObjects (bulk delete) operation.
///
/// Contains information about which objects were successfully deleted
/// and which failed. Returned by ``R2Client/deleteObjects(bucket:keys:)``.
///
/// ```swift
/// let result = try await client.deleteObjects(bucket: "bucket", keys: ["a.txt", "b.txt"])
/// print("Deleted: \(result.deleted.count), Errors: \(result.errors.count)")
/// ```
public struct R2DeleteObjectsResult: Sendable, Equatable {
    /// Objects that were successfully deleted.
    public let deleted: [DeletedObject]

    /// Objects that failed to delete.
    ///
    /// Check each ``DeleteError`` for the failure reason.
    public let errors: [DeleteError]

    public init(deleted: [DeletedObject], errors: [DeleteError] = []) {
        self.deleted = deleted
        self.errors = errors
    }

    /// Information about a successfully deleted object.
    public struct DeletedObject: Sendable, Equatable {
        /// The key of the deleted object.
        public let key: String

        /// The version ID of the deleted object, if versioning is enabled.
        public let versionId: String?

        /// Whether a delete marker was created instead of permanent deletion.
        ///
        /// This is `true` when versioning is enabled.
        public let deleteMarker: Bool

        /// Creates a new deleted object entry.
        ///
        /// - Parameters:
        ///   - key: The deleted object's key.
        ///   - versionId: The version ID, if applicable.
        ///   - deleteMarker: Whether a delete marker was created.
        public init(key: String, versionId: String? = nil, deleteMarker: Bool = false) {
            self.key = key
            self.versionId = versionId
            self.deleteMarker = deleteMarker
        }
    }

    /// An error that occurred when deleting an object.
    public struct DeleteError: Sendable, Equatable {
        /// The key of the object that failed to delete.
        public let key: String

        /// The error code from R2 (e.g., "AccessDenied").
        public let code: String

        /// The human-readable error message.
        public let message: String

        /// Creates a new delete error.
        ///
        /// - Parameters:
        ///   - key: The object key that failed.
        ///   - code: The error code.
        ///   - message: The error message.
        public init(key: String, code: String, message: String) {
            self.key = key
            self.code = code
            self.message = message
        }
    }
}
