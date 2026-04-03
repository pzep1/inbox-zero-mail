// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProviderCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ProviderCore",
            targets: ["ProviderCore"]
        ),
    ],
    dependencies: [
        .package(path: "../MailCore"),
        .package(url: "https://github.com/openid/AppAuth-iOS.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "ProviderCore",
            dependencies: [
                "MailCore",
                .product(name: "AppAuth", package: "AppAuth-iOS"),
            ]
        ),
        .testTarget(
            name: "ProviderCoreTests",
            dependencies: ["ProviderCore"]
        ),
    ]
)
