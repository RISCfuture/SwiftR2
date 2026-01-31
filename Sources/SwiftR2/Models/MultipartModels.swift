import Foundation

/// Result of initiating a multipart upload.
///
/// Returned by ``R2Client/createMultipartUpload(bucket:key:contentType:metadata:)``.
/// Use the ``uploadId`` for uploading parts and completing the upload.
public struct R2CreateMultipartUploadResult: Sendable, Equatable {
    /// The bucket where the multipart upload was initiated.
    public let bucket: String

    /// The key of the object being uploaded.
    public let key: String

    /// The unique identifier for this multipart upload.
    ///
    /// Use this ID with ``R2Client/uploadPart(bucket:key:uploadId:partNumber:body:)``
    /// and ``R2Client/completeMultipartUpload(bucket:key:uploadId:parts:)``.
    public let uploadId: String

    /// Creates a new multipart upload result.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - uploadId: The upload ID.
    public init(bucket: String, key: String, uploadId: String) {
        self.bucket = bucket
        self.key = key
        self.uploadId = uploadId
    }
}

/// Result of uploading a part in a multipart upload.
///
/// Returned by ``R2Client/uploadPart(bucket:key:uploadId:partNumber:body:)``.
public struct R2UploadPartResult: Sendable, Equatable {
    /// The part number that was uploaded.
    public let partNumber: Int

    /// The entity tag (ETag) of the uploaded part.
    ///
    /// Required when completing the multipart upload.
    public let etag: String

    /// Creates a new upload part result.
    ///
    /// - Parameters:
    ///   - partNumber: The part number.
    ///   - etag: The ETag of the part.
    public init(partNumber: Int, etag: String) {
        self.partNumber = partNumber
        self.etag = etag
    }
}

/// A completed part for finalizing a multipart upload.
///
/// Create instances from ``R2UploadPartResult`` values and pass them to
/// ``R2Client/completeMultipartUpload(bucket:key:uploadId:parts:)``.
///
/// Conforms to `Codable` for use with ``ResumableUploadState``.
public struct R2CompletedPart: Sendable, Equatable, Codable {
    /// The part number (1-10000).
    public let partNumber: Int

    /// The entity tag (ETag) of the part.
    public let etag: String

    /// Creates a completed part reference.
    ///
    /// - Parameters:
    ///   - partNumber: The part number.
    ///   - etag: The ETag from the upload response.
    public init(partNumber: Int, etag: String) {
        self.partNumber = partNumber
        self.etag = etag
    }
}

/// Result of completing a multipart upload.
///
/// Returned by ``R2Client/completeMultipartUpload(bucket:key:uploadId:parts:)``.
/// The ``etag`` of the final object is different from individual part ETags.
public struct R2CompleteMultipartUploadResult: Sendable, Equatable {
    /// The bucket containing the uploaded object.
    public let bucket: String

    /// The key of the uploaded object.
    public let key: String

    /// The entity tag (ETag) of the completed object.
    ///
    /// For multipart uploads, this is a hash of the part ETags with a suffix
    /// indicating the number of parts (e.g., `"abc123-5"` for 5 parts).
    public let etag: String

    /// The full URL of the uploaded object, if provided.
    public let location: String?

    /// Creates a new complete multipart upload result.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - etag: The final ETag.
    ///   - location: The object URL, if available.
    public init(bucket: String, key: String, etag: String, location: String? = nil) {
        self.bucket = bucket
        self.key = key
        self.etag = etag
        self.location = location
    }
}

/// Information about an in-progress multipart upload.
///
/// Represents an upload that was initiated but not yet completed or aborted.
public struct R2MultipartUpload: Sendable, Equatable {
    /// The key of the object being uploaded.
    public let key: String

    /// The unique identifier for this upload.
    public let uploadId: String

    /// When the multipart upload was initiated.
    public let initiated: Date

    /// The storage class for the object.
    public let storageClass: StorageClass

    /// Creates a new multipart upload info.
    ///
    /// - Parameters:
    ///   - key: The object key.
    ///   - uploadId: The upload ID.
    ///   - initiated: When the upload was initiated.
    ///   - storageClass: The storage class.
    public init(
        key: String,
        uploadId: String,
        initiated: Date,
        storageClass: StorageClass = .standard
    ) {
        self.key = key
        self.uploadId = uploadId
        self.initiated = initiated
        self.storageClass = storageClass
    }
}

/// Information about an uploaded part in a multipart upload.
///
/// Contains details about a part that has been uploaded but the overall
/// upload has not yet been completed.
public struct R2Part: Sendable, Equatable {
    /// The part number (1-10000).
    public let partNumber: Int

    /// When the part was uploaded.
    public let lastModified: Date

    /// The entity tag (ETag) of the part.
    public let etag: String

    /// The size of the part in bytes.
    public let size: Int64

    /// Creates a new part info.
    ///
    /// - Parameters:
    ///   - partNumber: The part number.
    ///   - lastModified: When the part was uploaded.
    ///   - etag: The part's ETag.
    ///   - size: The part size in bytes.
    public init(partNumber: Int, lastModified: Date, etag: String, size: Int64) {
        self.partNumber = partNumber
        self.lastModified = lastModified
        self.etag = etag
        self.size = size
    }
}
