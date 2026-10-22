import AppKit
import SwiftUI

/// A brief message near the top of the screen with the pointer. Never takes focus or clicks.
@MainActor
enum Toast {
    private static var panel: NSPanel?
    private static var dismissal: Task<Void, Never>?

    static func show(_ message: String, symbol: String) {
        dismissal?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let view = NSHostingView(rootView: ToastView(message: message, symbol: symbol))
        panel.contentView = view
        let size = view.fittingSize
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let origin = CGPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 24)
            panel.setFrame(CGRect(origin: origin, size: size), display: true)
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        dismissal = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            } completionHandler: {
                // A newer toast may have reset the alpha while this one faded.
                Task { @MainActor in if panel.alphaValue == 0 { panel.orderOut(nil) } }
            }
        }
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }
}

private struct ToastView: View {
    let message: String
    let symbol: String

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .fixedSize()
    }
}
