// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Still",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Still", targets: ["Still"])],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "StillCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "Still", dependencies: ["StillCore"]),
        .testTarget(name: "StillCoreTests", dependencies: ["StillCore"])
    ]
)
