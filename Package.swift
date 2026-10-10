// swift-tools-version: 5.10
// Package.swift tells Swift Package Manager (Apple's built-in build tool) what to build.
// We build one executable called "Styxpad" from the files in Sources/Styxpad.

import PackageDescription

let package = Package(
    name: "Styxpad",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Styxpad")
    ]
)
