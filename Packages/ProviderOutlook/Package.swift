// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProviderOutlook",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ProviderOutlook",
            targets: ["ProviderOutlook"]
        ),
    ],
    dependencies: [
        .package(path: "../MailCore"),
        .package(path: "../ProviderCore"),
    ],
    targets: [
        .target(
            name: "ProviderOutlook",
            dependencies: [
                "MailCore",
                "ProviderCore",
            ]
        ),
        .testTarget(
            name: "ProviderOutlookTests",
            dependencies: ["ProviderOutlook"]
        ),
    ]
)
