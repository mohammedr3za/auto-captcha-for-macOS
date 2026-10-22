import AppKit
import ApplicationServices
import CoreGraphics

enum Permissions {
    /// Needed to read Safari's page structure and to type the answer.
    static var accessibility: Bool { AXIsProcessTrusted() }
    /// Needed to capture the CAPTCHA image. macOS only reports a new grant after a relaunch.
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }

    static func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func requestScreenRecording() {
        // Prompts only the first time; after that the switch is only in System Settings.
        if !CGRequestScreenCaptureAccess() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    /// Starts a fresh copy once this one has quit (and released the hotkey), so new grants apply.
    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
