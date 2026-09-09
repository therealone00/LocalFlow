// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalFlow",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LocalFlow",
            targets: ["LocalFlow"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.18.0")
    ],
    targets: [
        .executableTarget(
            name: "LocalFlow",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/LocalFlow",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "LocalFlowTests",
            dependencies: ["LocalFlow"],
            path: "Tests/LocalFlowTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
