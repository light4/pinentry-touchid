// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "pinentry-touchid",
  platforms: [.macOS(.v13)],
  products: [.executable(name: "pinentry-touchid", targets: ["PinentryTouchID"])],
  targets: [.executableTarget(name: "PinentryTouchID")]
)
