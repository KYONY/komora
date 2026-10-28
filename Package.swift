// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Komora",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "KomoraCore"),
        .executableTarget(name: "Komora", dependencies: ["KomoraCore"],
                          linkerSettings: [.linkedFramework("Carbon")]),
        .testTarget(name: "KomoraCoreTests", dependencies: ["KomoraCore"]),
    ]
)
