// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AppUpdates",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "AppUpdates",
            targets: ["AppUpdates"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1"),
    ],
    targets: [
        .target(
            name: "AppUpdates",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
    ]
)
