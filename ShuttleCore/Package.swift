// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ShuttleCore",
    platforms: [.macOS("15.0"), .watchOS("26.0")],
    products: [
        .library(name: "ShuttleCore", targets: ["ShuttleCore"])
    ],
    targets: [
        .target(name: "ShuttleCore"),
        .testTarget(name: "ShuttleCoreTests", dependencies: ["ShuttleCore"]),
    ]
)
