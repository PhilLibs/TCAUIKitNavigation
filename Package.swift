// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "TCAUIKitNavigation",
    platforms: [
      .iOS(.v13),
      .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "TCAUIKitNavigation",
            targets: ["TCAUIKitNavigation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "TCAUIKitNavigation",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "TCAUIKitNavigationTests",
            dependencies: ["TCAUIKitNavigation"]),
    ]
)
