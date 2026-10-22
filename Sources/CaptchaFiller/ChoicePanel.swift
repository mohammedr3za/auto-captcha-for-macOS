import AppKit
import SwiftUI

/// Shows the CAPTCHA beside the differing readings so the user can pick the right one.
@MainActor
final class ChoicePanel {
    private let panel = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private var monitor: Any?
    private var continuation: CheckedContinuation<String?, Never>?

    /// Keys 1–9 or a click pick an option, Return takes the first, Esc cancels (nil).
    /// The panel takes key input without activating this app, so the browser keeps its focus.
    static func choose(from options: [String], image: CGImage, below anchor: CGRect) async -> String? {
        let chooser = ChoicePanel()
        return await withCheckedContinuation {
            chooser.show(Array(options.prefix(9)), image: image, below: anchor, resuming: $0)
        }
    }

    private init() {
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
    }

    private func show(_ options: [String], image: CGImage, below anchor: CGRect,
                      resuming continuation: CheckedContinuation<String?, Never>) {
        self.continuation = continuation
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53:  // Esc
                finish(nil)
            case 36, 76:  // Return, Enter
                finish(options[0])
            default:
                guard let digit = event.charactersIgnoringModifiers.flatMap({ Int($0) }),
                      options.indices.contains(digit - 1)
                else { return event }
                finish(options[digit - 1])
            }
            return nil
        }

        let view = NSHostingView(rootView: ChoiceView(
            image: NSImage(cgImage: image, size: .zero), options: options, onPick: { [weak self] in self?.finish($0) }
        ))
        panel.contentView = view
        panel.setFrame(frame(for: view.fittingSize, below: anchor.flippedVertically), display: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func finish(_ choice: String?) {
        guard let continuation else { return }
        self.continuation = nil
        if let monitor { NSEvent.removeMonitor(monitor) }
        panel.orderOut(nil)
        panel.contentView = nil
        continuation.resume(returning: choice)
    }

    /// Just below `anchor` (AppKit coordinates), or above it when there's no room, kept on screen.
    private func frame(for size: CGSize, below anchor: CGRect) -> CGRect {
        var origin = CGPoint(x: anchor.minX, y: anchor.minY - size.height - 8)
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            if origin.y < visible.minY { origin.y = anchor.maxY + 8 }
        }
        return CGRect(origin: origin, size: size)
    }
}

private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct ChoiceView: View {
    let image: NSImage
    let options: [String]
    let onPick: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The readings differ. Which is right?")
                .font(.headline)
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: 288, maxHeight: 90)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button { onPick(option) } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(option)
                            .font(.system(.title3, design: .monospaced))
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("Press 1–\(options.count) · Esc to cancel")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
