import Foundation

/// Solves the simple arithmetic some CAPTCHAs ask for: "7 + 3", "7+3=?", "What is seven plus three?".
public enum MathSolver {
    private enum Token: Equatable {
        case number(Int)
        case op(Character)
        case word(String)
    }

    private static let numberWords: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
        "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
        "nineteen": 19, "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60,
        "seventy": 70, "eighty": 80, "ninety": 90,
    ]
    private static let operatorWords: [String: Character] = [
        "plus": "+", "minus": "-", "times": "*", "multiplied": "*", "divided": "/",
        // A lone "x", as in "6 x 7" or "6x7".
        "x": "*",
    ]
    private static let operatorSymbols: [Character: Character] = [
        "+": "+", "-": "-", "−": "-", "–": "-", "*": "*", "×": "*", "·": "*", "÷": "/", "/": "/",
    ]
    /// The only words allowed around an expression read off an image (see `solve`).
    private static let questionWords: Set<String> = [
        "what", "whats", "is", "equals", "equal", "solve", "calculate", "compute",
        "the", "answer", "result", "to", "please", "enter", "type",
    ]

    /// - Parameter allowFiller: true for page text, where any words may surround the expression.
    ///   False for OCR of a CAPTCHA image: only question words may appear there, so a text
    ///   CAPTCHA such as "5X3AB" is never mistaken for 5 × 3.
    /// - Returns: nil when there is no expression, or it divides by zero or unevenly.
    public static func solve(_ text: String, allowFiller: Bool) -> Int? {
        let tokens = tokenize(text)
        if !allowFiller {
            for case .word(let word) in tokens where !questionWords.contains(word) { return nil }
        }
        // The first run of: number (operator number)+
        for start in tokens.indices {
            guard case .number(let first) = tokens[start] else { continue }
            var numbers = [first]
            var operators: [Character] = []
            var i = start + 1
            while i + 1 < tokens.count, case .op(let op) = tokens[i], case .number(let n) = tokens[i + 1] {
                operators.append(op)
                numbers.append(n)
                i += 2
            }
            if !operators.isEmpty { return evaluate(numbers, operators) }
        }
        return nil
    }

    private static func tokenize(_ text: String) -> [Token] {
        let chars = Array(text.lowercased())
        var tokens: [Token] = []
        // Set right after "twenty", "thirty"…, so "twenty one" and "twenty-one" become 21.
        var afterTensWord = false
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isASCII, c.isNumber {
                var j = i
                while j < chars.count, chars[j].isASCII, chars[j].isNumber { j += 1 }
                let digits = String(chars[i..<j])
                // Long digit runs aren't CAPTCHA arithmetic (and could overflow).
                tokens.append(digits.count <= 6 ? .number(Int(digits)!) : .word(digits))
                afterTensWord = false
                i = j
            } else if c.isLetter {
                var j = i
                while j < chars.count, chars[j].isLetter { j += 1 }
                let word = String(chars[i..<j])
                i = j
                if let n = numberWords[word] {
                    if afterTensWord, n < 10, case .number(let tens)? = tokens.last {
                        tokens[tokens.count - 1] = .number(tens + n)
                        afterTensWord = false
                    } else {
                        tokens.append(.number(n))
                        afterTensWord = n >= 20
                    }
                    continue
                }
                afterTensWord = false
                if let op = operatorWords[word] {
                    tokens.append(.op(op))
                } else if word == "by", case .op(_)? = tokens.last {
                    // "multiplied by", "divided by": the operator already covers both words.
                } else {
                    tokens.append(.word(word))
                }
            } else {
                // A hyphen joining two words ("twenty-one") isn't subtraction.
                let joinsWords = c == "-" && i > 0 && i + 1 < chars.count
                    && chars[i - 1].isLetter && chars[i + 1].isLetter
                if !joinsWords, let op = operatorSymbols[c] {
                    tokens.append(.op(op))
                    afterTensWord = false
                }
                i += 1
            }
        }
        return tokens
    }

    /// × and ÷ bind tighter than + and −.
    private static func evaluate(_ numbers: [Int], _ operators: [Character]) -> Int? {
        var terms = [numbers[0]]
        var signs: [Character] = []
        for (op, n) in zip(operators, numbers.dropFirst()) {
            switch op {
            case "*":
                let (product, overflow) = terms[terms.count - 1].multipliedReportingOverflow(by: n)
                guard !overflow else { return nil }
                terms[terms.count - 1] = product
            case "/":
                guard n != 0, terms[terms.count - 1] % n == 0 else { return nil }
                terms[terms.count - 1] /= n
            default:
                terms.append(n)
                signs.append(op)
            }
        }
        return zip(signs, terms.dropFirst()).reduce(terms[0]) { $1.0 == "+" ? $0 + $1.1 : $0 - $1.1 }
    }
}
