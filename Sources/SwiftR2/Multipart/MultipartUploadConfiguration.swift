import Foundation

/// Configuration for multipart uploads.
///
/// Controls how large files are split and uploaded in parallel.
/// Use with ``MultipartUploadManager`` for fine-grained control.
///
/// ```swift
/// let config = MultipartUploadConfiguration(
///     partSize: 10 * 1024 * 1024,  // 10MB parts
///     maxConcurrentUploads: 6       // 6 parallel uploads
/// )
/// let manager = MultipartUploadManager(client: client, configuration: config)
/// ```
public struct MultipartUploadConfiguration: Sendable {
    /// The minimum part size (5MB) as required by S3/R2.
    public static let minimumPartSize = 5 * 1024 * 1024

    /// The maximum part size (5GB) as allowed by S3/R2.
    public static let maximumPartSize = 5 * 1024 * 1024 * 1024

    /// The default configuration with 8MB parts and 4 concurrent uploads.
    public static let `default` = Self()

    /// The size of each part in bytes.
    ///
    /// Must be at least 5MB (5,242,880 bytes) per S3 specification.
    /// Larger parts mean fewer requests but higher memory usage.
    /// Defaults to 8MB.
    public let partSize: Int

    /// The maximum number of concurrent part uploads.
    ///
    /// Higher values can improve throughput but use more bandwidth
    /// and connections. Defaults to 4.
    public let maxConcurrentUploads: Int

    /// Whether to automatically retry failed part uploads.
    ///
    /// When enabled, failed parts are retried with exponential backoff.
    /// Defaults to `true`.
    public let retryFailedParts: Bool

    /// The maximum number of retry attempts for each part.
    ///
    /// Only applies when ``retryFailedParts`` is `true`. Defaults to 3.
    public let maxRetryAttempts: Int

    /// Creates a multipart upload configuration.
    /// - Parameters:
    ///   - partSize: The size of each part. Defaults to 8MB.
    ///   - maxConcurrentUploads: Maximum concurrent uploads. Defaults to 4.
    ///   - retryFailedParts: Whether to retry failed parts. Defaults to true.
    ///   - maxRetryAttempts: Maximum retry attempts per part. Defaults to 3.
    public init(
        partSize: Int = 8 * 1024 * 1024,
        maxConcurrentUploads: Int = 4,
        retryFailedParts: Bool = true,
        maxRetryAttempts: Int = 3
    ) {
        self.partSize = max(partSize, Self.minimumPartSize)
        self.maxConcurrentUploads = max(1, maxConcurrentUploads)
        self.retryFailedParts = retryFailedParts
        self.maxRetryAttempts = max(0, maxRetryAttempts)
    }
}
