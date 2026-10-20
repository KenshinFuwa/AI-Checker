// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [.library(name: "AICheckerCore", targets: ["AICheckerCore"])]
var targets: [Target] = [
    .target(name: "AICheckerCore"),
    .testTarget(name: "AICheckerCoreTests", dependencies: ["AICheckerCore"])
]
#if os(macOS)
products.append(.executable(name: "AIChecker", targets: ["AIChecker"]))
// Public source builds rely on the built-in vector fallbacks.
// Third-party brand PNGs are not redistributed.
targets.append(.executableTarget(name: "AIChecker", dependencies: ["AICheckerCore"]))
#endif
let package = Package(
    name: "AIChecker",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
