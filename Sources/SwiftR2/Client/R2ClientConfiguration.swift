import Foundation

/// Configuration for an ``R2Client``.
///
/// Use this structure to customize client behavior including credentials,
/// network configuration, and timeouts.
///
/// ```swift
/// let config = R2ClientConfiguration(
///     accountId: "your-account-id",
///     credentialsProvider: EnvironmentCredentialsProvider(),
///     timeoutInterval: 120
/// )
/// let client = R2Client(configuration: config)
/// ```
public struct R2ClientConfiguration: Sendable {
    /// The region for AWS Signature V4 signing.
    ///
    /// Cloudflare R2 always uses `"auto"` as the region.
    public static let region = "auto"

    /// The service name for AWS Signature V4 signing.
    ///
    /// R2 uses `"s3"` for S3 compatibility.
    public static let service = "s3"

    /// The Cloudflare account ID.
    ///
    /// Find this in the Cloudflare dashboard under Account ID.
    public let accountId: String

    /// The credentials provider for authentication.
    ///
    /// See ``CredentialsProvider`` for available implementations.
    public let credentialsProvider: any CredentialsProvider

    /// The URL session configuration to use for network requests.
    ///
    /// Defaults to `.default`. Customize this to configure caching,
    /// connection pooling, or proxy settings.
    public let urlSessionConfiguration: URLSessionConfiguration

    /// The timeout interval for requests, in seconds.
    ///
    /// Defaults to 60 seconds. Increase this for large file operations.
    public let timeoutInterval: TimeInterval

    /// The R2 endpoint URL derived from the account ID.
    public var endpoint: URL {
        URL(string: "https://\(accountId).r2.cloudflarestorage.com")!
    }

    /// Creates a new R2 client configuration.
    /// - Parameters:
    ///   - accountId: The Cloudflare account ID.
    ///   - credentialsProvider: The credentials provider to use.
    ///   - urlSessionConfiguration: The URL session configuration. Defaults to `.default`.
    ///   - timeoutInterval: The timeout interval for requests. Defaults to 60 seconds.
    public init(
        accountId: String,
        credentialsProvider: any CredentialsProvider,
        urlSessionConfiguration: URLSessionConfiguration = .default,
        timeoutInterval: TimeInterval = 60
    ) {
        self.accountId = accountId
        self.credentialsProvider = credentialsProvider
        self.urlSessionConfiguration = urlSessionConfiguration
        self.timeoutInterval = timeoutInterval
    }

    /// Creates a new R2 client configuration with static credentials.
    /// - Parameters:
    ///   - accountId: The Cloudflare account ID.
    ///   - accessKeyId: The access key ID.
    ///   - secretAccessKey: The secret access key.
    ///   - urlSessionConfiguration: The URL session configuration. Defaults to `.default`.
    ///   - timeoutInterval: The timeout interval for requests. Defaults to 60 seconds.
    public init(
        accountId: String,
        accessKeyId: String,
        secretAccessKey: String,
        urlSessionConfiguration: URLSessionConfiguration = .default,
        timeoutInterval: TimeInterval = 60
    ) {
        self.accountId = accountId
        self.credentialsProvider = StaticCredentialsProvider(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey
        )
        self.urlSessionConfiguration = urlSessionConfiguration
        self.timeoutInterval = timeoutInterval
    }
}
