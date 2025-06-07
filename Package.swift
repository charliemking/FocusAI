// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "MLCChat",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MLCChat",
            targets: ["MLCChat"]
        ),
        .library(
            name: "MLCChatTestSupport",
            targets: ["MLCChatTestSupport"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/NetworkImage", from: "6.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
        .package(path: "ios/MLCSwift"),
        .package(path: "TestPackage")
    ],
    targets: [
        .target(
            name: "MLCChat",
            dependencies: [
                "MLCSwift",
                "NetworkImage",
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "MLCChat",
            exclude: ["Assets.xcassets"],
            resources: [
                .process("Assets.xcassets")
            ],
            swiftSettings: [
                .define("RELEASE", .when(configuration: .release))
            ]
        ),
        .target(
            name: "MLCChatTestSupport",
            dependencies: [
                .product(name: "TestCore", package: "TestPackage")
            ],
            path: "Tests/MLCChatTestSupport"
        ),
        .testTarget(
            name: "MLCChatTests",
            dependencies: [
                "MLCChat",
                "MLCChatTestSupport"
            ],
            path: "Tests/MLCChatTests",
            swiftSettings: [
                .define("TEST")
            ]
        ),
        .testTarget(
            name: "MLCChatUITests",
            dependencies: [
                "MLCChat",
                "MLCChatTestSupport"
            ],
            path: "Tests/MLCChatUITests",
            swiftSettings: [
                .define("TEST")
            ]
        )
    ]
) 