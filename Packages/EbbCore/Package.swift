// swift-tools-version:5.9
import PackageDescription

// EbbCore holds all of Ebb's app-independent logic: the symptom catalog,
// the on-device pattern finder, the stage estimate and the doctor-report
// builder. It only depends on Foundation, so it can be built and unit-tested
// on any platform (including CI on Linux).
let package = Package(
    name: "EbbCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EbbCore", targets: ["EbbCore"])
    ],
    targets: [
        .target(name: "EbbCore"),
        .testTarget(name: "EbbCoreTests", dependencies: ["EbbCore"])
    ]
)
