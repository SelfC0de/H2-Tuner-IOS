// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "H2Tuner",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/wanliyunyan/LibXray.git", branch: "main")
    ],
    targets: [
        .target(
            name: "H2Tuner",
            dependencies: ["LibXray"]
        )
    ]
)
