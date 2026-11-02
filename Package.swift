// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BitChord",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BitChordCore",
            targets: ["BitChordCore"]
        ),
        .library(
            name: "BitChordUI",
            targets: ["BitChordUI"]
        ),
        .executable(
            name: "BitChordTestsRunner",
            targets: ["BitChordTestsRunner"]
        )
    ],
    targets: [
        .target(
            name: "BitChordCore",
            path: "Sources/BitChordCore"
        ),
        .target(
            name: "BitChordUI",
            dependencies: ["BitChordCore"],
            path: "Sources/BitChordUI"
        ),
        .executableTarget(
            name: "BitChordTestsRunner",
            dependencies: ["BitChordCore"],
            path: "Tests/BitChordTestsRunner"
        )
    ]
)
