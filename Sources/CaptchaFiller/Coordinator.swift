import AppKit
import CaptchaCore
import Carbon.HIToolbox
import ImageIO
import ScreenCaptureKit
import ServiceManagement

/// Runs a fill: find the CAPTCHA, read or solve it, type the answer.
@MainActor
final class Coordinator: ObservableObject {
    @Published private(set) var status = "Press ⌃⌥C on a page with a CAPTCHA"
    @Published private(set) var hasAccessibility = Permissions.accessibility
    @Published private(set) var hasScreenRecording = Permissions.screenRecording
    @Published private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled

    /// The last captured CAPTCHA and its cleaned-up version, for checking misreads.
    static let captureDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("CaptchaFiller", isDirectory: true)

    /// `defaults write local.captchafiller OllamaModel <name>` picks another Ollama model, and
    /// `KeepCase -bool true` types the model's own upper and lower case instead of capitals.
    private let reader = OllamaReader(
        model: UserDefaults.standard.string(forKey: "OllamaModel") ?? OllamaReader.defaultModel,
        uppercasesReading: !UserDefaults.standard.bool(forKey: "KeepCase")
    )
    private var hotKey: HotKey?
    private var isFilling = false

    init() {
        hotKey = HotKey(keyCode: kVK_ANSI_C, modifiers: controlKey | optionKey) { [weak self] in
            Task { await self?.fill() }
        }
        if hotKey == nil { status = "⌃⌥C is taken by another app; use the menu" }
        // Grants happen in System Settings, so poll to keep the menu current.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
    }

    func refreshPermissions() {
        hasAccessibility = Permissions.accessibility
        hasScreenRecording = Permissions.screenRecording
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            report("Couldn't change Launch at Login: \(error.localizedDescription)", symbol: "exclamationmark.triangle")
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    func showLastCapture() {
        NSWorkspace.shared.open(Self.captureDirectory)
    }

    /// - Parameter selectingArea: skip detection and go straight to dragging a box.
    func fill(selectingArea: Bool = false) async {
        guard !isFilling else { return }
        isFilling = true
        defer { isFilling = false }

        refreshPermissions()
        guard hasAccessibility else {
            report("Grant Accessibility access first", symbol: "lock")
            Permissions.requestAccessibility()
            return
        }
        guard hasScreenRecording else {
            report("Grant Screen Recording access, then relaunch", symbol: "lock")
            Permissions.requestScreenRecording()
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }

        // Load the model while the page is searched, so it's ready when the image is.
        let reader = self.reader
        Task.detached { await reader.warmUp() }

        var target: CaptchaTarget?
        var field: AXUIElement?
        if !selectingArea, let id = app.bundleIdentifier, SafariSnapshot.bundleIDs.contains(id) {
            let pid = app.processIdentifier
            if let snapshot = await Task.detached(operation: { SafariSnapshot.capture(pid: pid) }).value,
               let found = CaptchaLocator.locate(in: snapshot.nodes) {
                target = found
                field = snapshot.elements[found.fieldIndex]
            }
        }

        if let question = target?.question, let value = MathSolver.solve(question, allowFiller: true) {
            await deliver(String(value), to: field, in: app)
            return
        }

        var region = target?.imageFrame
        if region == nil {
            region = await RegionPicker.pick()
            // Let the overlay leave the screen before capturing.
            try? await Task.sleep(for: .milliseconds(150))
        }
        guard let region else {
            app.activate()
            report("Cancelled", symbol: "xmark.circle")
            return
        }

        let image: CGImage
        do {
            // No inset: CAPTCHAs are often drawn to the image's edge, and an inset cut off the last
            // character. Borders caught in a dragged box are thin lines that cleanup erases.
            image = try await SCScreenshotManager.captureImage(in: region)
        } catch {
            app.activate()
            report("Screen capture failed: \(error.localizedDescription)", symbol: "exclamationmark.triangle")
            return
        }

        Toast.show("Reading the CAPTCHA…", symbol: "hourglass")
        let answer: Answer
        var note = ""
        if let reading = try? await reader.read(image) {
            saveCapture(image, cleaned: nil)
            answer = AnswerPicker.pick(readings: [reading])
        } else {
            let ocr = await Task.detached(operation: { TextReader.readings(of: image) }).value
            saveCapture(image, cleaned: ocr.cleaned)
            answer = AnswerPicker.pick(readings: ocr.readings)
            note = " with Apple OCR (Ollama isn't running)"
        }

        switch answer {
        case .none:
            app.activate()
            report("Couldn't read the CAPTCHA\(note)", symbol: "questionmark.circle")
        case .single(let text):
            await deliver(text, to: field, in: app, note: note)
        case .choice(let options):
            if let text = await ChoicePanel.choose(from: options, image: image, below: region) {
                await deliver(text, to: field, in: app, note: note)
            } else {
                app.activate()
                report("Cancelled", symbol: "xmark.circle")
            }
        }
    }

    /// Types into the detected field, else into whatever field has focus, else copies the answer.
    private func deliver(_ answer: String, to field: AXUIElement?, in app: NSRunningApplication, note: String = "") async {
        if let field {
            await Typist.fill(field, with: answer, in: app)
            report("Typed \(answer)\(note)", symbol: "checkmark.circle")
        } else if await Typist.fillFocusedField(with: answer, in: app) {
            report("Typed \(answer)\(note)", symbol: "checkmark.circle")
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(answer, forType: .string)
            report("Copied \(answer): click the box and press ⌘V", symbol: "doc.on.clipboard")
        }
    }

    private func report(_ message: String, symbol: String) {
        status = message
        Toast.show(message, symbol: symbol)
    }

    private func saveCapture(_ image: CGImage, cleaned: CGImage?) {
        let directory = Self.captureDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files: [(String, CGImage?)] = [("last-capture.png", image), ("last-capture-cleaned.png", cleaned)]
        for (name, picture) in files {
            let url = directory.appendingPathComponent(name)
            guard let picture else {
                // Don't leave a cleaned image from an earlier capture next to this one.
                try? FileManager.default.removeItem(at: url)
                continue
            }
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
            else { continue }
            CGImageDestinationAddImage(destination, picture, nil)
            CGImageDestinationFinalize(destination)
        }
    }
}
