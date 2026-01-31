import Foundation

/// A protocol for providing R2 credentials.
///
/// Implement this protocol to provide credentials from various sources
/// such as environment variables, configuration files, or credential rotation services.
///
/// SwiftR2 includes several built-in implementations:
/// - ``StaticCredentialsProvider``: Returns fixed credentials
/// - ``EnvironmentCredentialsProvider``: Reads from environment variables
/// - ``ChainedCredentialsProvider``: Tries multiple providers in order
///
/// ## Implementing a Custom Provider
///
/// ```swift
/// struct KeychainCredentialsProvider: CredentialsProvider {
///     func credentials() async throws -> R2Credentials {
///         // Fetch from keychain
///         let accessKeyId = try keychain.get("r2-access-key-id")
///         let secretKey = try keychain.get("r2-secret-key")
///         return R2Credentials(accessKeyId: accessKeyId, secretAccessKey: secretKey)
///     }
/// }
/// ```
public protocol CredentialsProvider: Sendable {
    /// Retrieves the current credentials.
    ///
    /// This method may be called multiple times during the client's lifetime.
    /// Implementations should cache credentials if retrieval is expensive.
    ///
    /// - Returns: The R2 credentials for signing requests.
    /// - Throws: ``R2Error/missingCredentials(_:)`` if credentials cannot be retrieved.
    func credentials() async throws -> R2Credentials
}

/// A credentials provider that returns static credentials.
///
/// Use this provider when credentials are known at initialization time.
/// For production applications, consider ``EnvironmentCredentialsProvider``
/// to avoid hardcoding secrets.
///
/// ```swift
/// let provider = StaticCredentialsProvider(
///     accessKeyId: "AKIAIOSFODNN7EXAMPLE",
///     secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
/// )
/// ```
public struct StaticCredentialsProvider: CredentialsProvider {
    private let _credentials: R2Credentials

    /// Creates a static credentials provider from an ``R2Credentials`` instance.
    ///
    /// - Parameter credentials: The credentials to provide.
    public init(credentials: R2Credentials) {
        self._credentials = credentials
    }

    /// Creates a static credentials provider from key strings.
    ///
    /// - Parameters:
    ///   - accessKeyId: The access key ID.
    ///   - secretAccessKey: The secret access key.
    public init(accessKeyId: String, secretAccessKey: String) {
        self._credentials = R2Credentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey
        )
    }

    public func credentials() throws -> R2Credentials {
        _credentials
    }
}

/// A credentials provider that reads from environment variables.
///
/// Reads `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` environment variables.
/// This is the recommended approach for server-side applications.
///
/// ```swift
/// // Set environment variables before running:
/// // export R2_ACCESS_KEY_ID=your-access-key
/// // export R2_SECRET_ACCESS_KEY=your-secret-key
///
/// let provider = EnvironmentCredentialsProvider()
/// let config = R2ClientConfiguration(
///     accountId: "your-account-id",
///     credentialsProvider: provider
/// )
/// ```
public struct EnvironmentCredentialsProvider: CredentialsProvider {
    /// The environment variable name for the access key ID.
    ///
    /// Default: `"R2_ACCESS_KEY_ID"`
    public static let accessKeyIdVariable = "R2_ACCESS_KEY_ID"

    /// The environment variable name for the secret access key.
    ///
    /// Default: `"R2_SECRET_ACCESS_KEY"`
    public static let secretAccessKeyVariable = "R2_SECRET_ACCESS_KEY"

    /// Creates an environment credentials provider.
    public init() {}

    public func credentials() throws -> R2Credentials {
        guard let accessKeyId = ProcessInfo.processInfo.environment[Self.accessKeyIdVariable] else {
            throw R2Error.missingCredentials(
                "Environment variable \(Self.accessKeyIdVariable) not set"
            )
        }

        guard let secretAccessKey = ProcessInfo.processInfo.environment[Self.secretAccessKeyVariable] else {
            throw R2Error.missingCredentials(
                "Environment variable \(Self.secretAccessKeyVariable) not set"
            )
        }

        return R2Credentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey
        )
    }
}

/// A credentials provider that chains multiple providers together.
///
/// Tries each provider in order until one succeeds. Useful for falling back
/// from one credential source to another.
///
/// ```swift
/// let provider = ChainedCredentialsProvider(providers: [
///     EnvironmentCredentialsProvider(),
///     StaticCredentialsProvider(accessKeyId: "fallback", secretAccessKey: "key")
/// ])
/// ```
public struct ChainedCredentialsProvider: CredentialsProvider {
    private let providers: [any CredentialsProvider]

    /// Creates a chained credentials provider.
    ///
    /// - Parameter providers: The providers to try in order. The first provider
    ///   that returns credentials successfully will be used.
    public init(providers: [any CredentialsProvider]) {
        self.providers = providers
    }

    public func credentials() async throws -> R2Credentials {
        var lastError: Error?

        for provider in providers {
            do {
                return try await provider.credentials()
            } catch {
                lastError = error
            }
        }

        throw lastError ?? R2Error.missingCredentials("No credentials providers configured")
    }
}
