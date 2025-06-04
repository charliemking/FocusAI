// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FocusAI",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "FocusAI",
            targets: ["FocusAI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mlc-ai/mlc-llm-swift.git", branch: "main")
    ],
    targets: [
        .target(
            name: "FocusAI",
            dependencies: [
                .product(name: "MLCLLM", package: "mlc-llm-swift")
            ],
            path: "FocusAI"),
        .testTarget(
            name: "FocusAITests",
            dependencies: ["FocusAI"],
            path: "FocusAITests"),
    ]
) 