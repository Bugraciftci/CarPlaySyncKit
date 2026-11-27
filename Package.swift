// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CarPlaySyncKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CarPlaySyncKit",
            targets: ["CarPlaySyncKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3")
    ],
    targets: [
        .target(
            name: "CarPlaySyncKit",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "CarPlaySyncKitTests",
            dependencies: ["CarPlaySyncKit"]
        )
    ]
)
