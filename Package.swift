// swift-tools-version: 6.2
import PackageDescription

let upcomingFeatures: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances"),
  .enableUpcomingFeature("ImmutableWeakCaptures"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .strictMemorySafety()
]

let package = Package(
  name: "SwiftR2",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v26), .iOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26), .macCatalyst(.v26)
  ],
  products: [
    .library(name: "SwiftR2", targets: ["SwiftR2"])
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0")
  ],
  targets: [
    .target(
      name: "SwiftR2",
      dependencies: [
        .product(name: "Crypto", package: "swift-crypto")
      ],
      resources: [.process("Resources")],
      swiftSettings: upcomingFeatures
    ),
    .testTarget(
      name: "SwiftR2Tests",
      dependencies: ["SwiftR2"],
      swiftSettings: upcomingFeatures
    )
  ],
  swiftLanguageModes: [.v5, .v6]
)
