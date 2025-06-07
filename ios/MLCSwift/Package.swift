// swift-tools-version:5.9

import PackageDescription

#if os(iOS)
let platformFramework = "UIKit"
#else
let platformFramework = "AppKit"
#endif

let package = Package(
    name: "MLCSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MLCSwift",
            targets: ["MLCSwift"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MLCEngineObjC",
            path: "Sources/ObjC",
            cSettings: [
                // DLPack headers first
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/ffi/3rdparty/dlpack/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/3rdparty/dlpack/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/dlpack/include"),
                // Then TVM and other headers
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/3rdparty/dmlc-core/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/3rdparty/picojson"),
                .headerSearchPath("../../mlc-llm/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/tokenizers-cpp/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/sentencepiece/src")
            ],
            cxxSettings: [
                // DLPack headers first
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/ffi/3rdparty/dlpack/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/3rdparty/dlpack/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/dlpack/include"),
                // Then TVM and other headers
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/mlc-core/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/3rdparty/dmlc-core/include"),
                .headerSearchPath("../../mlc-llm/3rdparty/tvm/ffi/include"),
                .unsafeFlags([
                    "-I../../mlc-llm/3rdparty/tvm/ffi/3rdparty/dlpack/include",
                    "-I../../mlc-llm/3rdparty/tvm/3rdparty/dlpack/include",
                    "-I../../mlc-llm/3rdparty/dlpack/include",
                    "-I../../mlc-llm/3rdparty/tvm/include",
                    "-I../../mlc-llm/3rdparty/tvm/3rdparty/dmlc-core/include",
                    "-I../../mlc-llm/3rdparty/tvm/ffi/include",
                    "-std=c++17"
                ]),
                .define("TVM_USE_LIBBACKTRACE", to: "0"),
                .define("DMLC_USE_LOGGING_LIBRARY", to: "\"tvm/runtime/logging.h\"")
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework(platformFramework)
            ]
        ),
        .target(
            name: "MLCSwift",
            dependencies: ["MLCEngineObjC"],
            path: "Sources/Swift",
            sources: ["LLMEngine.swift", "OpenAIProtocol.swift", "MLCTypes.swift"]
        )
    ],
    cxxLanguageStandard: .cxx17
)
