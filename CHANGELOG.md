# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Simplified the signing code's cryptography import. Built as a SwiftPM
  dependency on Apple platforms, swift-crypto's `Crypto` module is a
  re-export of `CryptoKit`, so the `#if canImport(CryptoKit)` fallbacks and
  the Linux-only dependency condition are gone in favor of a plain
  `import Crypto`. No behavioral change on any platform.

## [1.2.1] - 2026-09-14

### Changed

- The package declares `swiftLanguageModes: [.v5, .v6]`, so it builds in
  either language mode and consumers who have not adopted Swift 6 mode are
  unaffected. Four further upcoming-feature flags (`ImmutableWeakCaptures`,
  `MemberImportVisibility`, `ExistentialAny`, `InternalImportsByDefault`)
  are enabled for this package's own targets. The required tools version
  stays at 6.2 and the public API is unchanged.
- Raised the swift-docc-plugin requirement to 1.5.0. The swift-crypto range
  (`3.0.0..<5.0.0`) is unchanged.

### Fixed

- The published documentation site's root URL resolves to the SwiftR2
  landing page instead of serving DocC's not-found view.

## [1.2.0] - 2026-07-06

### Added

- Linux support. AWS SigV4 signing uses swift-crypto on non-Apple platforms,
  `URLSession`/XML parsing are guarded behind
  `FoundationNetworking`/`FoundationXML`, the async byte-streaming download path
  is reimplemented on top of `URLSessionDataDelegate` (open-source Foundation
  lacks `URLSession.bytes`), and a `String(localized:)` shim covers error
  strings. Apple platforms are unaffected and continue to use CryptoKit.

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
