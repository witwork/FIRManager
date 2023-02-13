// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FIRManager",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FIRManager",
            targets: ["FIRManager"]),
    ],
    dependencies: [
        .package( url: "https://github.com/lmirosevic/GBDeviceInfo.git", branch: "master"),
        .package( url: "https://github.com/firebase/firebase-ios-sdk.git", branch: "master"),
        .package( url: "https://github.com/google/GoogleSignIn-iOS.git", branch: "main")
       
    ],
    targets: [
        .target(
            name: "FIRManager",
            dependencies: [
            ],
            path: "FIRManager",
            sources: ["FIRManager.m"],
            publicHeadersPath: ""
        ),
        
    ]
)
