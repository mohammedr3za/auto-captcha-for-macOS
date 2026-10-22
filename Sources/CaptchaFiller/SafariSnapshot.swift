import AppKit
import ApplicationServices
import CaptchaCore

/// The web content of Safari's front window, flattened into `PageNode`s for `CaptchaLocator`,
/// with the accessibility element behind each node kept for typing into.
struct SafariSnapshot {
    let nodes: [PageNode]
    let elements: [AXUIElement]

    static let bundleIDs: Set<String> = ["com.apple.Safari", "com.apple.SafariTechnologyPreview"]

    private enum Attribute: Int, CaseIterable {
        case role, subrole, title, description, placeholder, help, value, position, size, children
        case domIdentifier, domClassList, url

        var name: String {
            switch self {
            case .role: kAXRoleAttribute
            case .subrole: kAXSubroleAttribute
            case .title: kAXTitleAttribute
            case .description: kAXDescriptionAttribute
            case .placeholder: "AXPlaceholderValue"
            case .help: kAXHelpAttribute
            case .value: kAXValueAttribute
            case .position: kAXPositionAttribute
            case .size: kAXSizeAttribute
            case .children: kAXChildrenAttribute
            case .domIdentifier: "AXDOMIdentifier"
            case .domClassList: "AXDOMClassList"
            case .url: "AXURL"
            }
        }
    }

    private static let attributeNames = Attribute.allCases.map(\.name) as CFArray

    /// Walks the focused window depth-first, keeping text fields, images and static text inside
    /// web areas. Stops after `limit` elements so huge pages don't stall the hotkey.
    static func capture(pid: pid_t, limit: Int = 8000) -> SafariSnapshot? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1.0)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID()
        else { return nil }

        var nodes: [PageNode] = []
        var elements: [AXUIElement] = []
        var stack: [(element: AXUIElement, inWebArea: Bool)] = [(window as! AXUIElement, false)]
        var visited = 0
        while let next = stack.popLast(), visited < limit {
            visited += 1
            var valuesRef: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(next.element, attributeNames, [], &valuesRef) == .success,
                  let values = valuesRef as? [AnyObject]
            else { continue }
            func string(_ attribute: Attribute) -> String { values[attribute.rawValue] as? String ?? "" }

            let role = string(.role)
            let inWebArea = next.inWebArea || role == "AXWebArea"
            if inWebArea, let kind = kind(role: role, subrole: string(.subrole)),
               let frame = frame(values[Attribute.position.rawValue], values[Attribute.size.rawValue]) {
                let classes = (values[Attribute.domClassList.rawValue] as? [String])?.joined(separator: " ") ?? ""
                let url = (values[Attribute.url.rawValue] as? URL)?.absoluteString ?? ""
                let label = [string(.title), string(.description), string(.placeholder), string(.help),
                             string(.domIdentifier), classes, url]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                nodes.append(PageNode(kind: kind, label: label, text: kind == .text ? string(.value) : "", frame: frame))
                elements.append(next.element)
            }

            let children = (values[Attribute.children.rawValue] as? [AnyObject] ?? []).compactMap { child in
                CFGetTypeID(child) == AXUIElementGetTypeID() ? (child as! AXUIElement) : nil
            }
            // Reversed so the first child is popped first, keeping document order.
            stack.append(contentsOf: children.reversed().map { ($0, inWebArea) })
        }
        return SafariSnapshot(nodes: nodes, elements: elements)
    }

    private static func kind(role: String, subrole: String) -> PageNode.Kind? {
        switch role {
        case "AXTextField": ["AXSecureTextField", "AXSearchField"].contains(subrole) ? nil : .textField
        case "AXImage": .image
        case "AXStaticText": .text
        default: nil
        }
    }

    /// nil for elements with no position or an empty size (hidden inputs and the like).
    private static func frame(_ position: AnyObject, _ size: AnyObject) -> CGRect? {
        guard CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &extent),
              extent.width > 0, extent.height > 0
        else { return nil }
        return CGRect(origin: origin, size: extent)
    }
}
