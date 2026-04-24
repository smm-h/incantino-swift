// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Incantino",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Incantino", targets: ["Incantino"]),
        .library(name: "IncantinoUI", targets: ["IncantinoUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "Incantino",
            dependencies: ["Yams"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "IncantinoUI",
            dependencies: ["Incantino"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "IncantinoTests",
            dependencies: ["Incantino"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "IncantinoUITests",
            dependencies: ["IncantinoUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
