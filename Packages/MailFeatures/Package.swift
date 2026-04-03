// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MailFeatures",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "MailFeatures",
            targets: ["MailFeatures"]
        ),
    ],
    dependencies: [
        .package(path: "../MailCore"),
        .package(path: "../MailData"),
    ],
    targets: [
        .target(
            name: "MailFeatures",
            dependencies: [
                "MailCore",
                "MailData",
            ]
        ),
        .testTarget(
            name: "MailFeaturesTests",
            dependencies: ["MailFeatures"]
        ),
    ]
)
