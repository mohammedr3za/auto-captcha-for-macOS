import AppKit

/// Full-screen crosshair overlay for dragging a box around the CAPTCHA.
@MainActor
final class RegionPicker {
    private var windows: [NSWindow] = []
    private var continuation: CheckedContinuation<CGRect?, Never>?

    /// The dragged box in global Core Graphics coordinates, or nil if Esc was pressed.
    static func pick() async -> CGRect? {
        let picker = RegionPicker()
        return await withCheckedContinuation { picker.show(resuming: $0) }
    }

    private func show(resuming continuation: CheckedContinuation<CGRect?, Never>) {
        self.continuation = continuation
        NSApp.activate()
        let mouse = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onFinish = { [weak self, weak window] selection in
                self?.finish(selection.flatMap { window?.convertToScreen($0) })
            }
            window.contentView = view
            windows.append(window)
            if screen.frame.contains(mouse) {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
        }
    }

    private func finish(_ selection: CGRect?) {
        guard let continuation else { return }
        self.continuation = nil
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        continuation.resume(returning: selection?.flippedVertically)
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    /// Called with the selection in window coordinates, or nil when cancelled.
    var onFinish: ((CGRect?) -> Void)?
    private var anchor: CGPoint?
    private var current: CGPoint?

    private var selection: CGRect? {
        guard let anchor, let current else { return nil }
        return CGRect(x: min(anchor.x, current.x), y: min(anchor.y, current.y),
                      width: abs(anchor.x - current.x), height: abs(anchor.y - current.y))
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil)
        current = anchor
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let selection, selection.width >= 8, selection.height >= 8 else {
            anchor = nil
            current = nil
            needsDisplay = true
            return
        }
        onFinish?(convert(selection, to: nil))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Esc
            onFinish?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        let hint = "Drag around the CAPTCHA · Esc to cancel" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = hint.size(withAttributes: attributes)
        hint.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.maxY - 80), withAttributes: attributes)

        guard let selection else { return }
        NSColor.clear.setFill()
        selection.fill(using: .copy)
        NSColor.white.setStroke()
        let outline = NSBezierPath(rect: selection.insetBy(dx: -0.5, dy: -0.5))
        outline.lineWidth = 1
        outline.stroke()
    }
}
