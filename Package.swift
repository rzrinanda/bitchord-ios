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
            name: "BitChord",
            targets: ["BitChord"]
        ),
        .executable(
            name: "BitChordTestsRunner",
            targets: ["BitChordTestsRunner"]
        )
    ],
    targets: [
        .target(
            name: "BitChord",
            path: "Sources/BitChordCore"
        ),
        .executableTarget(
            name: "BitChordTestsRunner",
            dependencies: ["BitChord"],
            path: "Tests/BitChordTestsRunner"
        )
    ]
)
