import Foundation

/// Credentials for authenticating with Cloudflare R2.
///
/// Obtain these credentials from the Cloudflare dashboard under
/// R2 > Manage R2 API Tokens.
///
/// ## Security Considerations
///
/// Never hardcode credentials in source code. Instead, use:
/// - ``EnvironmentCredentialsProvider`` for environment variables
/// - ``ChainedCredentialsProvider`` to try multiple sources
/// - A custom ``CredentialsProvider`` for secure credential storage
public struct R2Credentials: Sendable, Equatable {
    /// The access key ID for R2 API authentication.
    ///
    /// This is the public identifier for your API token.
    public let accessKeyId: String

    /// The secret access key for R2 API authentication.
    ///
    /// Keep this value secure. It is used to sign requests.
    public let secretAccessKey: String

    /// Creates new R2 credentials.
    ///
    /// - Parameters:
    ///   - accessKeyId: The access key ID from the Cloudflare dashboard.
    ///   - secretAccessKey: The secret access key from the Cloudflare dashboard.
    public init(accessKeyId: String, secretAccessKey: String) {
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
    }
}
