// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuietMicIntents",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .library(
            name: "QuietMicIntents",
            targets: ["QuietMicIntents"]
        )
    ],
    targets: [
        .target(
            name: "QuietMicIntents",
            swiftSettings: [
                // Match Xcode build setting SWIFT_STRICT_CONCURRENCY = complete.
                // See Swift concurrency migration guidance for flag parity.
                .unsafeFlags(["-strict-concurrency=complete"], .when(configuration: .debug)),
                .unsafeFlags(["-strict-concurrency=complete"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "QuietMicIntentsTests",
            dependencies: ["QuietMicIntents"],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"], .when(configuration: .debug)),
                .unsafeFlags(["-strict-concurrency=complete"], .when(configuration: .release))
            ]
        )
    ]
)
