# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-26

### Changed

- Adopted the Approachable Concurrency upcoming-feature flags
  (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`).
  Nonisolated `async` work — such as iterating an `R2DownloadStream` — now
  runs on the caller's executor by default, avoiding an extra executor hop.
  No source changes are required at call sites.
- Modernized the multipart upload retry backoff to use
  `Task.sleep(for: .seconds(_:))` (behavior and cancellation semantics
  unchanged).
- Removed an outdated `@preconcurrency` qualifier from the internal
  CryptoKit import; the CryptoKit types in use are already
  `Sendable`-audited.

## [1.0.0] - 2026-01-30

### Added

- Initial release of SwiftR2
- Full R2 API support for Cloudflare R2 storage
- AWS Signature Version 4 signing implementation
- Multi-platform support: macOS, iOS, tvOS, watchOS, visionOS, macCatalyst
- Swift 6 concurrency support with strict concurrency checking
- Comprehensive documentation
