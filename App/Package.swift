// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HostsWitch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "HostsWitch", path: "Sources/HostsWitch")
    ]
)
