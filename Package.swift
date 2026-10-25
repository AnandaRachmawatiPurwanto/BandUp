// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BandUpCore",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [.library(name: "BandUpCore", targets: ["BandUpCore"])],
    targets: [
        .target(name: "BandUpCore", path: "Sources/BandUpCore", resources: [.process("Resources")]),
        .testTarget(name: "BandUpCoreTests", dependencies: ["BandUpCore"], path: "Tests/BandUpCoreTests"),
    ]
)
