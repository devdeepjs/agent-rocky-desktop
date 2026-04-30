// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgentRockyDesktop",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AgentRocky", targets: ["AgentRocky"])
    ],
    targets: [
        .executableTarget(name: "AgentRocky"),
        .testTarget(name: "AgentRockyTests", dependencies: ["AgentRocky"])
    ]
)
