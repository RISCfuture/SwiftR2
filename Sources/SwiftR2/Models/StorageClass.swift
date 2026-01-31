import Foundation

/// The storage class for an R2 object.
///
/// Cloudflare R2 supports different storage classes with varying
/// cost and availability characteristics.
public enum StorageClass: String, Sendable, Codable, CaseIterable {
    /// Standard storage class.
    ///
    /// The default storage class with high availability and low latency.
    case standard = "STANDARD"

    /// Infrequent Access storage class.
    ///
    /// Lower storage cost for data accessed less frequently,
    /// with slightly higher retrieval costs.
    case standardIA = "STANDARD_IA"
}
