// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftR2",
    defaultLocalization: "en",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1), .macCatalyst(.v16)],
    products: [
        .library(name: "SwiftR2", targets: ["SwiftR2"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    ],
    targets: [
        .target(
            name: "SwiftR2",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(name: "SwiftR2Tests", dependencies: ["SwiftR2"]),
    ]
)
