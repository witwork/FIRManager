// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FIRManager",
    platforms: [
        .iOS(.v11),
    ],
    products: [
        .library(name: "FIRManager", targets: ["FIRManagerTarget"])
    ],
    dependencies: [
        .package( url: "https://github.com/lmirosevic/GBDeviceInfo.git", branch: "master"),
        .package(name: "Firebase", url: "https://github.com/firebase/firebase-ios-sdk.git", branch: "master"),
        .package(name: "GoogleSignIn", url: "https://github.com/google/GoogleSignIn-iOS.git", branch: "main")
    ],
    targets: [
        .target(
            name: "FIRManagerTarget",
            dependencies: [
                .product(name: "FirebaseAuth", package: "Firebase"),
                .product(name: "FirebaseFirestore", package: "Firebase"),
                .product(name: "FirebaseCrashlytics", package: "Firebase"),
                .product(name: "FirebaseAnalytics", package: "Firebase"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn"),
                .product(name: "GBDeviceInfo", package: "GBDeviceInfo")
            ],
            path: "FIRManager",
            sources: ["FIRManager.m"],
            publicHeadersPath: "."
        ),
        
    ]
)
