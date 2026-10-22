import AppKit
import ApplicationServices

/// Types answers with synthesized key events. Needs Accessibility access.
@MainActor
enum Typist {
    /// Brings `app` forward, focuses `field` and types `text` over its current contents.
    static func fill(_ field: AXUIElement, with text: String, in app: NSRunningApplication) async {
        await bringForward(app)
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        try? await Task.sleep(for: .milliseconds(40))
        selectContents(of: field)
        await type(text)
    }

    /// Types into the element with keyboard focus in `app`. Returns false without typing when
    /// that element isn't a text field.
    static func fillFocusedField(with text: String, in app: NSRunningApplication) async -> Bool {
        await bringForward(app)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return false }
        let field = focused as! AXUIElement
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(field, kAXRoleAttribute as CFString, &roleRef)
        guard let role = roleRef as? String, ["AXTextField", "AXTextArea", "AXComboBox"].contains(role) else {
            return false
        }
        selectContents(of: field)
        await type(text)
        return true
    }

    private static func bringForward(_ app: NSRunningApplication) async {
        guard !app.isActive else { return }
        app.activate()
        for _ in 0..<20 where !app.isActive {
            try? await Task.sleep(for: .milliseconds(25))
        }
        // Let the app hand focus back to the field that had it.
        try? await Task.sleep(for: .milliseconds(120))
    }

    /// Selects the field's text so typing replaces it. (Not ⌘A: that key code is Q on AZERTY
    /// layouts, and ⌘Q would quit the browser.)
    private static func selectContents(of field: AXUIElement) {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &value)
        var range = CFRange(location: 0, length: (value as? String)?.utf16.count ?? 0)
        guard range.length > 0, let selection = AXValueCreate(.cfRange, &range) else { return }
        AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, selection)
    }

    /// One key press per character that carries the character itself, so the keyboard layout
    /// doesn't matter. Waits for the shortcut's modifier keys to be released first.
    private static func type(_ text: String) async {
        let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        for _ in 0..<40 where !CGEventSource.flagsState(.hidSystemState).intersection(modifiers).isEmpty {
            try? await Task.sleep(for: .milliseconds(25))
        }
        let source = CGEventSource(stateID: .hidSystemState)
        for unit in text.utf16 {
            var character = unit
            for keyDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown) else { continue }
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
                event.post(tap: .cghidEventTap)
            }
            try? await Task.sleep(for: .milliseconds(4))
        }
    }
}
