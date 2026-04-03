// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProviderGmail",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ProviderGmail",
            targets: ["ProviderGmail"]
        ),
    ],
    dependencies: [
        .package(path: "../MailCore"),
        .package(path: "../ProviderCore"),
    ],
    targets: [
        .target(
            name: "ProviderGmail",
            dependencies: [
                "MailCore",
                "ProviderCore",
            ]
        ),
        .testTarget(
            name: "ProviderGmailTests",
            dependencies: ["ProviderGmail"]
        ),
    ]
)
