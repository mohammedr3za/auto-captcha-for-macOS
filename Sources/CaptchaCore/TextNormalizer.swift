import Foundation

public enum TextNormalizer {
    /// Cyrillic and Greek letters Vision sometimes returns for Latin letters and digits.
    private static let lookalikes: [Character: Character] = [
        "А": "A", "В": "B", "Е": "E", "З": "3", "К": "K", "М": "M", "Н": "H", "О": "O",
        "Р": "P", "С": "C", "Т": "T", "У": "Y", "Х": "X",
        "а": "a", "б": "6", "в": "B", "е": "e", "з": "3", "к": "K", "м": "M", "н": "H",
        "о": "o", "р": "p", "с": "c", "т": "T", "у": "y", "х": "x",
        "Α": "A", "Β": "B", "Ε": "E", "Ζ": "Z", "Η": "H", "Ι": "I", "Κ": "K", "Μ": "M",
        "Ν": "N", "Ο": "O", "Ρ": "P", "Τ": "T", "Υ": "Y", "Χ": "X",
    ]

    /// Reduces OCR output to the ASCII letters and digits a text CAPTCHA is made of.
    public static func normalize(_ text: String) -> String {
        let mapped = String(text.map { lookalikes[$0] ?? $0 })
        let folded = mapped.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
        return String(String.UnicodeScalarView(folded.unicodeScalars.filter {
            $0.isASCII && CharacterSet.alphanumerics.contains($0)
        }))
    }
}
