// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CrossPromoSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "CrossPromoSDK",
            targets: ["CrossPromoSDK"]
        ),
    ],
    targets: [
        .target(
            name: "CrossPromoSDK"
        ),
        .testTarget(
            name: "CrossPromoSDKTests",
            dependencies: ["CrossPromoSDK"]
        ),
    ]
)
