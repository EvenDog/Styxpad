// swift-tools-version: 5.10
// Package.swift tells Swift Package Manager (Apple's built-in build tool) what to build.
// We build one executable called "TartarusMac" from the files in Sources/TartarusMac.

import PackageDescription

let package = Package(
    name: "TartarusMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "TartarusMac")
    ]
)
