// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGit2",
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftGit2",
            targets: ["SwiftGit2"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            name: "Clibgit2",
            url: "https://github.com/thebaselab/Clibgit2",
            .branch("master")
        ),
        .package(
            name: "ZipArchive",
            url: "https://github.com/ZipArchive/ZipArchive.git",
            .upToNextMajor(from: "2.4.3")
        ),
        .package(
            name: "Quick",
            url: "https://github.com/Quick/Quick.git",
            .upToNextMajor(from: "4.0.0")
        ),
        .package(
            name: "Nimble",
            url: "https://github.com/Quick/Nimble.git",
            .upToNextMajor(from: "9.2.1")
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftGit2",
            dependencies: ["Clibgit2", "ZipArchive"],
            path: "SwiftGit2"
        ),
        .testTarget(
            name: "SwiftGit2Tests",
            dependencies: ["SwiftGit2", "Quick", "Nimble"],
            path: "SwiftGit2Tests",
            resources: [
                .copy("Fixtures/")
            ]
        )
    ]
)
