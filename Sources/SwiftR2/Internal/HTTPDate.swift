import Foundation

extension Date {
  /// Parses the value of an HTTP date header, such as `Last-Modified`.
  ///
  /// Accepts the IMF-fixdate form RFC 9110 mandates — `EEE, dd MMM yyyy HH:mm:ss GMT` —
  /// which is what S3-compatible services emit.
  ///
  /// - Parameter header: The raw header value.
  /// - Returns: The date the header denotes, or `nil` if it isn't a valid HTTP date.
  static func parsingHTTPHeader(_ header: String) -> Date? {
    try? Date(header, strategy: .http)
  }
}
