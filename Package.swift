// swift-tools-version: 5.9
import PackageDescription
import Foundation
let standalone = ProcessInfo.processInfo.environment["STILL_STANDALONE_TESTS"] == "1"

let package = Package(
    name: "Still",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Still", targets: ["Still"])],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "StillCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "Still", dependencies: ["StillCore"]),
        standalone
            ? .executableTarget(name: "StillCoreChecks", dependencies: ["StillCore", "CSQLite"], path: "Tests/StillCoreTests", swiftSettings: [.define("STILL_STANDALONE")])
            : .testTarget(name: "StillCoreTests", dependencies: ["StillCore"], exclude: ["main.swift"])
    ]
)
