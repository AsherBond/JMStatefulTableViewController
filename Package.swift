// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JMStatefulTableViewController",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "JMStatefulTableViewController",
            targets: ["JMStatefulTableViewController"]
        ),
    ],
    targets: [
        .target(
            name: "JMStatefulTableViewController",
            dependencies: [],
            path: "Sources/JMStatefulTableViewController"
        ),
        .testTarget(
            name: "JMStatefulTableViewControllerTests",
            dependencies: ["JMStatefulTableViewController"],
            path: "Tests/JMStatefulTableViewControllerTests"
        ),
    ]
)
