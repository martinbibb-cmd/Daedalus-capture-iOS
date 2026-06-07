// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DaedalusContracts",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DaedalusContracts",
            targets: ["DaedalusContracts"]
        )
    ],
    targets: [
        .target(name: "DaedalusContracts"),
        .testTarget(
            name: "DaedalusContractsTests",
            dependencies: ["DaedalusContracts"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
