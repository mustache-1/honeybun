// swift-tools-version:5.9
import PackageDescription

// A tiny tool that draws Honeybun's Home screen in real SwiftUI and saves it as a PNG, so the design can be
// seen without an iPhone. It is a preview only; it isn't part of the app.
let package = Package(
    name: "Preview",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Preview", path: "Sources/Preview")]
)
