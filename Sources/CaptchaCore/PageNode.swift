import CoreGraphics

/// One element of a web page, flattened from the accessibility tree in document order.
public struct PageNode: Equatable {
    public enum Kind {
        case textField
        case image
        case text
    }

    public var kind: Kind
    /// Descriptive attributes joined: title, description, placeholder, DOM id and classes, image URL.
    public var label: String
    /// Visible text, for `.text` nodes.
    public var text: String
    /// Screen frame in global coordinates, origin at the top-left of the primary display.
    public var frame: CGRect

    public init(kind: Kind, label: String = "", text: String = "", frame: CGRect) {
        self.kind = kind
        self.label = label
        self.text = text
        self.frame = frame
    }
}
