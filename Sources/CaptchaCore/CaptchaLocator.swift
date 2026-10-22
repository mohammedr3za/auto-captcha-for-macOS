import CoreGraphics
import Foundation

/// Where the CAPTCHA is on a page: the field to type into, and what to solve.
public struct CaptchaTarget: Equatable {
    /// Index into the nodes given to `CaptchaLocator.locate(in:)`.
    public var fieldIndex: Int
    /// The CAPTCHA image to read, when one sits next to the field.
    public var imageFrame: CGRect?
    /// Page text asking an arithmetic question, solved directly instead of reading an image.
    public var question: String?
}

/// Picks the CAPTCHA field by scoring every text field on CAPTCHA wording in its own label,
/// CAPTCHA wording or an arithmetic question just before it, and a CAPTCHA-shaped image beside it.
public enum CaptchaLocator {
    private static let keywords = try! Regex(
        #"captcha|security[ -]?code|verification[ -]?code|security check|human verification|anti-?spam|(enter|type) the (characters|code|text|letters|word)|characters (you see|shown|above|below|in the (image|picture))|are you (a )?human|(prove|confirm) (that )?you('re| are) (a )?human"#
    ).ignoresCase()
    /// Tells "What is 7 + 3?" apart from text that merely has hyphenated numbers, like a phone number.
    private static let questionHint = try! Regex(
        #"[=?+×÷*]|\b(what|solve|calculat|sum|plus|minus|times|multipl|divid)"#
    ).ignoresCase()

    /// Fields scoring below this aren't considered CAPTCHA fields.
    static let threshold = 5

    public static func locate(in nodes: [PageNode]) -> CaptchaTarget? {
        var best: (score: Int, target: CaptchaTarget)?
        for (i, field) in nodes.enumerated() where field.kind == .textField {
            let labelScore = field.label.contains(keywords) ? 6 : 0
            var question = isQuestion(field.label) ? field.label : nil
            var questionScore = question == nil ? 0 : 5
            var wordingScore = 0

            for (j, node) in nodes.enumerated() where node.kind == .text {
                let gap = distance(node.frame, field.frame)
                // Labels usually come right before their field in document order.
                let close = (i - 3..<i).contains(j) || gap <= 80
                guard close || gap <= 250 else { continue }
                if node.text.contains(keywords) { wordingScore = max(wordingScore, close ? 4 : 2) }
                if isQuestion(node.text), (close ? 5 : 3) > questionScore {
                    question = node.text
                    questionScore = close ? 5 : 3
                }
            }

            var imageFrame: CGRect?
            var imageScore = 0
            for node in nodes where node.kind == .image && isCaptchaShaped(node.frame) {
                let gap = distance(node.frame, field.frame)
                let nearness = gap <= 60 ? 3 : gap <= 150 ? 2 : gap <= 350 ? 1 : 0
                let wording = gap <= 150 && node.label.contains(keywords) ? 4 : 0
                if nearness + wording > imageScore {
                    imageScore = nearness + wording
                    imageFrame = node.frame
                }
            }

            let score = labelScore + wordingScore + questionScore + imageScore
            guard score >= threshold, score > (best?.score ?? 0) else { continue }
            best = (score, CaptchaTarget(
                fieldIndex: i,
                imageFrame: question == nil ? imageFrame : nil,
                question: question
            ))
        }
        return best?.target
    }

    static func isQuestion(_ text: String) -> Bool {
        text.count <= 120 && text.contains(questionHint) && MathSolver.solve(text, allowFiller: true) != nil
    }

    static func isCaptchaShaped(_ frame: CGRect) -> Bool {
        let aspect = frame.width / max(frame.height, 1)
        return (50...500).contains(frame.width) && (16...200).contains(frame.height)
            && (1.2...12).contains(aspect)
    }

    /// Gap between two rects; 0 when they touch or overlap.
    static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = max(0, a.minX - b.maxX, b.minX - a.maxX)
        let dy = max(0, a.minY - b.maxY, b.minY - a.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
