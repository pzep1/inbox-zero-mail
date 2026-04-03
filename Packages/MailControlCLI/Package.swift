// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MailControlCLI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "inboxctl",
            targets: ["MailControlCLI"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "MailControlCLI"
        ),
        .testTarget(
            name: "MailControlCLITests"
        ),
    ]
)
