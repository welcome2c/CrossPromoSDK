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
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "11.0.0"
        ),
    ],
    targets: [
        .target(
            name: "CrossPromoSDK",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "CrossPromoSDKTests",
            dependencies: ["CrossPromoSDK"]
        ),
    ]
)
