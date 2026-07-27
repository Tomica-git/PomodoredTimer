// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PomodoredTimer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PomodoredTimer", targets: ["PomodoredTimer"])
    ],
    targets: [
        .executableTarget(
            name: "PomodoredTimer",
            path: "Sources/PomodoredTimer",
            swiftSettings: [
                .define("EDITION_PUBLIC")
            ]
        ),
        .testTarget(
            name: "PomodoredTimerTests",
            dependencies: ["PomodoredTimer"],
            path: "Tests/PomodoredTimerTests",
            swiftSettings: [
                .define("EDITION_PUBLIC")
            ]
        )
    ]
)
