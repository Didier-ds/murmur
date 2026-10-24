// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Murmur",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "Murmur",
            path: "Sources/Murmur",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices"),
            ]
        )
    ]
)
