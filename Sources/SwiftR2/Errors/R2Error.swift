import Foundation

/// Errors that can occur when interacting with Cloudflare R2.
///
/// All ``R2Client`` methods throw `R2Error` when operations fail.
/// Use pattern matching to handle specific error cases:
///
/// ```swift
/// do {
///     let data = try await client.get(bucket: "my-bucket", key: "file.txt")
/// } catch R2Error.notFound(let bucket, let key) {
///     print("Object not found: \(bucket)/\(key ?? "")")
/// } catch R2Error.accessDenied(let message) {
///     print("Access denied: \(message)")
/// } catch R2Error.rateLimited(let retryAfter) {
///     if let delay = retryAfter {
///         try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
///     }
/// } catch {
///     print("Error: \(error)")
/// }
/// ```
public enum R2Error: Error, Sendable, Equatable {
  /// The requested object or bucket was not found.
  ///
  /// - Parameters:
  ///   - bucket: The bucket name.
  ///   - key: The object key, or `nil` if the bucket itself wasn't found.
  case notFound(bucket: String, key: String?)

  /// Access to the resource was denied.
  ///
  /// Check that your credentials have the necessary permissions.
  case accessDenied(message: String)

  /// The request was malformed or contained invalid parameters.
  case invalidRequest(message: String)

  /// A network error occurred during the request.
  ///
  /// This may be a transient error; consider retrying.
  case networkError(message: String)

  /// The response from R2 was invalid or could not be parsed.
  case invalidResponse(message: String)

  /// Credentials are missing or could not be retrieved.
  ///
  /// Check your ``CredentialsProvider`` configuration.
  case missingCredentials(String)

  /// The specified bucket does not exist.
  case bucketNotFound(bucket: String)

  /// The object already exists when using conditional request headers.
  case objectAlreadyExists(bucket: String, key: String)

  /// A conditional request precondition (If-Match, If-None-Match, etc.) failed.
  case preconditionFailed(message: String)

  /// The request was rate limited by R2.
  ///
  /// - Parameter retryAfter: Suggested delay before retrying, if provided.
  case rateLimited(retryAfter: TimeInterval?)

  /// An error occurred during a multipart upload operation.
  case multipartUploadError(message: String)

  /// A multipart upload was aborted.
  ///
  /// - Parameter uploadId: The ID of the aborted upload.
  case uploadAborted(uploadId: String)

  /// The content checksum did not match the expected value.
  ///
  /// - Parameters:
  ///   - expected: The expected checksum.
  ///   - actual: The actual checksum received.
  case checksumMismatch(expected: String, actual: String)

  /// An error returned directly by the R2 service.
  ///
  /// See ``R2ServiceError`` for detailed error information.
  case serviceError(R2ServiceError)

  /// An unexpected error occurred.
  case unknown(message: String)
}

extension R2Error: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case .notFound(_, let key):
        return key != nil
        ? String(localized: "Object not found.", bundle: .module)
        : String(localized: "Bucket not found.", bundle: .module)
      case .accessDenied:
        return String(localized: "Access denied.", bundle: .module)
      case .invalidRequest:
        return String(localized: "Invalid request.", bundle: .module)
      case .networkError:
        return String(localized: "Network error.", bundle: .module)
      case .invalidResponse:
        return String(localized: "Invalid response.", bundle: .module)
      case .missingCredentials:
        return String(localized: "Missing credentials.", bundle: .module)
      case .bucketNotFound:
        return String(localized: "Bucket not found.", bundle: .module)
      case .objectAlreadyExists:
        return String(localized: "Object already exists.", bundle: .module)
      case .preconditionFailed:
        return String(localized: "Precondition failed.", bundle: .module)
      case .rateLimited:
        return String(localized: "Rate limited.", bundle: .module)
      case .multipartUploadError:
        return String(localized: "Multipart upload error.", bundle: .module)
      case .uploadAborted:
        return String(localized: "Upload aborted.", bundle: .module)
      case .checksumMismatch:
        return String(localized: "Checksum mismatch.", bundle: .module)
      case .serviceError:
        return String(localized: "R2 service error.", bundle: .module)
      case .unknown:
        return String(localized: "Unknown error.", bundle: .module)
    }
  }

  public var failureReason: String? {
    switch self {
      case let .notFound(bucket, key):
        if let key {
          return String(localized: "The object “\(key)” does not exist in bucket '\(bucket)'.", bundle: .module)
        }
        return String(localized: "The bucket “\(bucket)” does not exist.", bundle: .module)
      case .accessDenied(let message):
        return message
      case .invalidRequest(let message):
        return message
      case .networkError(let message):
        return message
      case .invalidResponse(let message):
        return message
      case .missingCredentials(let message):
        return message
      case .bucketNotFound(let bucket):
        return String(localized: "The bucket “\(bucket)” does not exist.", bundle: .module)
      case let .objectAlreadyExists(bucket, key):
        return String(localized: "The object “\(key)” already exists in bucket '\(bucket)'.", bundle: .module)
      case .preconditionFailed(let message):
        return message
      case .rateLimited(let retryAfter):
        if let retryAfterS = retryAfter.map({ Measurement(value: $0, unit: UnitDuration.seconds) }) {
          return String(localized: "Retry after \(retryAfterS, format: .measurement(width: .narrow)) seconds.", bundle: .module)
        }
        return nil
      case .multipartUploadError(let message):
        return message
      case .uploadAborted(let uploadId):
        return String(localized: "The upload with ID “\(uploadId)” was aborted.", bundle: .module)
      case let .checksumMismatch(expected, actual):
        return String(localized: "Expected checksum “\(expected)” but received “\(actual)”.", bundle: .module)
      case .serviceError(let error):
        return error.failureReason
      case .unknown(let message):
        return message
    }
  }

  public var recoverySuggestion: String? {
    switch self {
      case .accessDenied:
        return String(localized: "Verify that your credentials have the required permissions.", bundle: .module)
      case .missingCredentials:
        return String(localized: "Check your credentials provider configuration.", bundle: .module)
      case .networkError:
        return String(localized: "This may be a transient error. Consider retrying the request.", bundle: .module)
      case .rateLimited(let retryAfter):
        if let retryAfterS = retryAfter.map({ Measurement(value: $0, unit: UnitDuration.seconds) }) {
          return String(localized: "Retry after \(retryAfterS, format: .measurement(width: .narrow)) seconds.", bundle: .module)
        }
        return String(localized: "Wait before retrying the request.", bundle: .module)
      case .checksumMismatch:
        return String(localized: "Verify the data integrity and retry the upload.", bundle: .module)
      case .multipartUploadError:
        return String(localized: "Check the upload configuration and retry.", bundle: .module)
      default:
        return nil
    }
  }
}

/// An error returned directly by the R2/S3 service.
///
/// Contains detailed information from the service response including
/// the error code, message, and request ID for debugging.
///
/// Access this through ``R2Error/serviceError(_:)``:
///
/// ```swift
/// catch R2Error.serviceError(let serviceError) {
///     print("Code: \(serviceError.code)")
///     print("Message: \(serviceError.message)")
///     print("Request ID: \(serviceError.requestId ?? "unknown")")
/// }
/// ```
public struct R2ServiceError: Error, Sendable, Equatable {
  /// The error code from R2 (e.g., "NoSuchKey", "AccessDenied").
  public let code: String

  /// The human-readable error message from R2.
  public let message: String

  /// The HTTP status code of the response.
  public let statusCode: Int

  /// The unique request ID for debugging.
  ///
  /// Include this when contacting Cloudflare support.
  public let requestId: String?

  /// The resource (bucket or object) that caused the error.
  public let resource: String?

  /// Creates a new R2 service error.
  ///
  /// - Parameters:
  ///   - code: The error code from R2.
  ///   - message: The error message.
  ///   - statusCode: The HTTP status code.
  ///   - requestId: The request ID, if available.
  ///   - resource: The resource that caused the error, if available.
  public init(
    code: String,
    message: String,
    statusCode: Int,
    requestId: String? = nil,
    resource: String? = nil
  ) {
    self.code = code
    self.message = message
    self.statusCode = statusCode
    self.requestId = requestId
    self.resource = resource
  }
}

extension R2ServiceError: LocalizedError {
  public var errorDescription: String? {
    String(localized: "R2 service error.", bundle: .module)
  }

  public var failureReason: String? {
    if let requestId {
      String(localized: "[\(code)] \(message) (Request ID: \(requestId))", bundle: .module)
    } else {
      String(localized: "[\(code)] \(message)", bundle: .module)
    }
  }
}
