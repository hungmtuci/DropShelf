// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DropShelf",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DropShelf", targets: ["DropShelf"])
    ],
    targets: [
        .executableTarget(
            name: "DropShelf",
            path: "Sources/DropShelf",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("QuickLookThumbnailing"),
                .linkedFramework("QuickLookUI"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)
