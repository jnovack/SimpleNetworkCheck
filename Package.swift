// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SimpleNetworkCheck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SimpleNetworkCheck", targets: ["SimpleNetworkCheck"])
    ],
    targets: [
        .executableTarget(
            name: "SimpleNetworkCheck",
            path: "Sources/SimpleNetworkCheck"
        ),
        .testTarget(
            name: "SimpleNetworkCheckTests",
            dependencies: ["SimpleNetworkCheck"],
            path: "Tests/SimpleNetworkCheckTests"
        )
    ]
)
