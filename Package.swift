// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorktreeLauncher",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WorktreeLauncher",
            path: "Sources/WorktreeLauncher"
        )
    ]
)
