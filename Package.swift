// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "TaskHostedAsyncSequence",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "TaskHostedAsyncSequence",
            targets: [
                "TaskHostedAsyncSequence"
            ]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "TaskHostedAsyncSequence",
            dependencies: []
        ),
        .testTarget(
            name: "TaskHostedAsyncSequenceTests",
            dependencies: [
                "TaskHostedAsyncSequence"
            ]
        ),
    ]
)
