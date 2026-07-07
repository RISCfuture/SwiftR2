import Foundation
#if canImport(FoundationNetworking)
  extension String {
    /// A source-compatible shim for the bundle-based `String(localized:bundle:)`
    /// initializer, which swift-corelibs-foundation doesn't implement at all. Falls
    /// back to the un-localized interpolated value.
    init(localized value: String, bundle: Bundle) {
      self = value
    }
  }
#endif
