// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftWS",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftWS",
            targets: ["SwiftWS"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.19.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services", from: "1.10.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftWS",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services")
            ]),
        .testTarget(
            name: "SwiftWSTests",
            dependencies: ["SwiftWS"]),
    ]
)
