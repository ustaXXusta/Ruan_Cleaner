// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacCleanerPro",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "MacCleanerPro",
            targets: ["MacCleanerPro"]),
    ],
    targets: [
        .executableTarget(
            name: "MacCleanerPro",
            path: "Sources/MacCleanerPro",
            resources: [
                .process("Assets")
            ]
        ),
    ]
)
