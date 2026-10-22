import SwiftUI

@main
struct CaptchaFillerApp: App {
    @StateObject private var coordinator: Coordinator

    init() {
        // Created eagerly (not when the menu first opens) so the hotkey works from launch.
        let coordinator = Coordinator()
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        MenuBarExtra("Captcha Filler", systemImage: "character.textbox") {
            MenuContent(coordinator: coordinator)
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var coordinator: Coordinator

    var body: some View {
        Button("Fill CAPTCHA") { Task { await coordinator.fill() } }
            .keyboardShortcut("c", modifiers: [.control, .option])
        Button("Select Area and Fill…") { Task { await coordinator.fill(selectingArea: true) } }
        Divider()
        Text(coordinator.status)
        Button("Show Last Capture") { coordinator.showLastCapture() }
        if !coordinator.hasAccessibility || !coordinator.hasScreenRecording {
            Divider()
            if !coordinator.hasAccessibility {
                Button("Grant Accessibility Access…") { Permissions.requestAccessibility() }
            }
            if !coordinator.hasScreenRecording {
                Button("Grant Screen Recording Access…") { Permissions.requestScreenRecording() }
            }
            Button("Relaunch to Apply Permissions") { Permissions.relaunch() }
        }
        Divider()
        Toggle("Launch at Login", isOn: Binding(
            get: { coordinator.launchesAtLogin },
            set: { coordinator.setLaunchesAtLogin($0) }
        ))
        Button("Quit Captcha Filler") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
