// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ShuttleCore",
    platforms: [.macOS("15.0"), .watchOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "ShuttleCore", targets: ["ShuttleCore"]),
        .library(name: "ShuttleStore", targets: ["ShuttleStore"]),
    ],
    targets: [
        // Règles métier pures : aucun framework Apple d'UI ou de stockage.
        .target(name: "ShuttleCore"),
        .testTarget(name: "ShuttleCoreTests", dependencies: ["ShuttleCore"]),
        // Sauvegarde des matchs avec SwiftData, testée sur Mac sans simulateur.
        .target(name: "ShuttleStore", dependencies: ["ShuttleCore"]),
        .testTarget(name: "ShuttleStoreTests", dependencies: ["ShuttleStore"]),
    ]
)
