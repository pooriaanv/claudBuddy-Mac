// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeBuddy",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: agent events, attention queue, behavior brain, animation math, strings.
        .target(name: "BuddyCore"),
        // The macOS app: windows, drawing, sound, settings, menu bar.
        .executableTarget(name: "ClaudeBuddy", dependencies: ["BuddyCore"]),
        .testTarget(name: "BuddyCoreTests", dependencies: ["BuddyCore"]),
    ]
)
