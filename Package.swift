// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftMarkdownReader",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // Main applications
        .executable(name: "MarkdownReader-iOS", targets: ["MarkdownReader-iOS"]),
        .executable(name: "MarkdownReader-macOS", targets: ["MarkdownReader-macOS"]),

        // Libraries that can be used by other packages
        .library(name: "MarkdownCore", targets: ["MarkdownCore"]),
        .library(name: "ViewerUI", targets: ["ViewerUI"]),
        .library(name: "FileAccess", targets: ["FileAccess"]),
        .library(name: "Search", targets: ["Search"]),
        .library(name: "Settings", targets: ["Settings"])
    ],
    dependencies: [
        // Swift Markdown for CommonMark parsing with GFM extensions
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.3.0"),
        // Collections for efficient data structures
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0")
    ],
    targets: [
        // MARK: - Application Targets

        // iOS Application
        .executableTarget(
            name: "MarkdownReader-iOS",
            dependencies: [
                "MarkdownCore",
                "ViewerUI",
                "FileAccess",
                "Search",
                "Settings"
            ],
            path: "Apps/MarkdownReader-iOS",
            resources: [
                .process("Assets.xcassets")
            ]
        ),

        // macOS Application
        .executableTarget(
            name: "MarkdownReader-macOS",
            dependencies: [
                "MarkdownCore",
                "ViewerUI",
                "FileAccess",
                "Search",
                "Settings"
            ],
            path: "Apps/MarkdownReader-macOS",
            resources: [
                .process("Assets.xcassets")
            ]
        ),

        // MARK: - Core Library Targets

        // Core Markdown parsing and rendering engine
        .target(
            name: "MarkdownCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "OrderedCollections", package: "swift-collections")
            ],
            path: "Packages/MarkdownCore/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // SwiftUI interface components
        .target(
            name: "ViewerUI",
            dependencies: [
                "MarkdownCore",
                "Settings"
            ],
            path: "Packages/ViewerUI/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Cross-platform file management
        .target(
            name: "FileAccess",
            dependencies: [],
            path: "Packages/FileAccess/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Document search and indexing
        .target(
            name: "Search",
            dependencies: [
                "MarkdownCore",
                .product(name: "OrderedCollections", package: "swift-collections")
            ],
            path: "Packages/Search/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Configuration management
        .target(
            name: "Settings",
            dependencies: [],
            path: "Packages/Settings/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // MARK: - Test Targets

        .testTarget(
            name: "MarkdownCoreTests",
            dependencies: ["MarkdownCore"],
            path: "Packages/MarkdownCore/Tests"
        ),

        .testTarget(
            name: "ViewerUITests",
            dependencies: ["ViewerUI"],
            path: "Packages/ViewerUI/Tests"
        ),

        .testTarget(
            name: "FileAccessTests",
            dependencies: ["FileAccess"],
            path: "Packages/FileAccess/Tests"
        ),

        .testTarget(
            name: "SearchTests",
            dependencies: ["Search"],
            path: "Packages/Search/Tests"
        ),

        .testTarget(
            name: "SettingsTests",
            dependencies: ["Settings"],
            path: "Packages/Settings/Tests"
        )
    ]
)