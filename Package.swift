// swift-tools-version:5.9
// SPM manifest exists ONLY to run the shared-spec conformance tests
// (`swift test`); the shipped library is built by CocoaPods via the podspec.
import PackageDescription

let package = Package(
  name: "KalendarCore",
  platforms: [.iOS(.v16), .macOS(.v13)],
  targets: [
    .target(name: "KalendarCore", path: "ios/Core"),
    .testTarget(name: "KalendarCoreTests", dependencies: ["KalendarCore"], path: "spec/swift"),
  ]
)
