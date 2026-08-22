// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SleepToggleMenu",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "SleepToggleMenu", targets: ["SleepToggleMenu"]),
    ],
    targets: [
        .target(name: "SleepToggleCore"),
        .executableTarget(
            name: "SleepToggleMenu",
            dependencies: ["SleepToggleCore"]
        ),
        .executableTarget(
            name: "SleepToggleMenuSelfTest",
            dependencies: ["SleepToggleCore"],
            path: "SelfTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
