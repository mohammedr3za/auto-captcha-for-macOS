// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CaptchaFiller",
    platforms: [.macOS("15.2")],
    targets: [
        // OCR, image cleanup, answer picking and CAPTCHA location: no UI, unit-tested.
        .target(name: "CaptchaCore"),
        // The menu bar app: hotkey, Safari accessibility, screen capture, typing, panels.
        .executableTarget(name: "CaptchaFiller", dependencies: ["CaptchaCore"]),
        .testTarget(
            name: "CaptchaCoreTests",
            dependencies: ["CaptchaCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
