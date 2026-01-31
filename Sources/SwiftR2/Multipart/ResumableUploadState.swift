import Foundation

/// State information for resuming a multipart upload.
///
/// Save this state to persistent storage to resume uploads that are
/// interrupted by app termination, network failures, or other issues.
///
/// ## Saving State
///
/// ```swift
/// // Encode to JSON for storage
/// let jsonData = try state.encoded()
/// UserDefaults.standard.set(jsonData, forKey: "upload-\(key)")
/// ```
///
/// ## Resuming an Upload
///
/// ```swift
/// // Decode from storage
/// let jsonData = UserDefaults.standard.data(forKey: "upload-\(key)")!
/// let state = try ResumableUploadState.decode(from: jsonData)
///
/// // Resume with the manager
/// let result = try await manager.resume(state: state, source: source)
/// ```
public struct ResumableUploadState: Codable, Sendable, Equatable {
    /// The bucket containing the upload.
    public let bucket: String

    /// The key of the object being uploaded.
    public let key: String

    /// The unique identifier for this multipart upload.
    public let uploadId: String

    /// The size of each part in bytes.
    public let partSize: Int

    /// The total file size in bytes, if known.
    public let totalSize: Int64?

    /// The parts that have been successfully uploaded.
    ///
    /// These parts will be skipped when resuming.
    public let completedParts: [R2CompletedPart]

    /// The total bytes uploaded so far.
    ///
    /// This is an estimate based on part count and size.
    public var bytesUploaded: Int64 {
        Int64(completedParts.count) * Int64(partSize)
    }

    /// The next part number that needs to be uploaded.
    public var nextPartNumber: Int {
        (completedParts.map(\.partNumber).max() ?? 0) + 1
    }

    /// Creates a new resumable upload state.
    ///
    /// - Parameters:
    ///   - bucket: The bucket name.
    ///   - key: The object key.
    ///   - uploadId: The upload ID.
    ///   - partSize: The size of each part.
    ///   - totalSize: The total file size, if known.
    ///   - completedParts: Parts already uploaded.
    public init(
        bucket: String,
        key: String,
        uploadId: String,
        partSize: Int,
        totalSize: Int64?,
        completedParts: [R2CompletedPart] = []
    ) {
        self.bucket = bucket
        self.key = key
        self.uploadId = uploadId
        self.partSize = partSize
        self.totalSize = totalSize
        self.completedParts = completedParts
    }

    /// Decodes state from JSON data.
    ///
    /// - Parameter data: JSON-encoded state data.
    /// - Returns: The decoded upload state.
    /// - Throws: A decoding error if deserialization fails.
    public static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    /// Returns a new state with an additional completed part.
    ///
    /// - Parameter part: The newly completed part to add.
    /// - Returns: A new state including the added part.
    public func adding(part: R2CompletedPart) -> Self {
        var parts = completedParts
        parts.append(part)
        return Self(
            bucket: bucket,
            key: key,
            uploadId: uploadId,
            partSize: partSize,
            totalSize: totalSize,
            completedParts: parts
        )
    }

    /// Encodes the state to JSON data for persistence.
    ///
    /// - Returns: JSON-encoded state data.
    /// - Throws: An encoding error if serialization fails.
    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
