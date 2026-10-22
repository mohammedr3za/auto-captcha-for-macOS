import AppKit

extension CGRect {
    /// Converts between Core Graphics global coordinates (origin at the top-left of the primary
    /// display; used by accessibility and screen capture) and AppKit screen coordinates (origin
    /// at its bottom-left). The conversion is its own inverse.
    @MainActor
    var flippedVertically: CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: minX, y: primaryHeight - maxY, width: width, height: height)
    }
}
