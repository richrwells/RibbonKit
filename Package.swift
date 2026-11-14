// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RibbonKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RibbonKit", targets: ["RibbonKit"])
    ],
    targets: [
        .target(name: "RibbonKit")
    ]
)
