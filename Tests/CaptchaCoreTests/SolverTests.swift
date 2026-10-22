import Testing
@testable import CaptchaCore

struct MathSolverTests {
    @Test(arguments: [
        ("7 + 3", 10), ("7+3=?", 10), ("12 × 4", 48), ("9 - 4", 5), ("8 ÷ 2", 4),
        ("2 + 3 * 4", 14), ("6x7", 42), ("What is 7 + 3?", 10),
    ])
    func solvesImageText(text: String, expected: Int) {
        #expect(MathSolver.solve(text, allowFiller: false) == expected)
    }

    @Test(arguments: ["TT783", "5X3AB", "UMLA6", "X5Y9A", "783", "7 / 2", "4 / 0", ""])
    func rejectsTextCaptchasAndBadArithmetic(text: String) {
        #expect(MathSolver.solve(text, allowFiller: false) == nil)
    }

    @Test(arguments: [
        ("What is seven plus three?", 10), ("Solve: twenty-one minus five", 16),
        ("6 multiplied by 7 = ?", 42), ("Spam check: what is 3 + 4", 7), ("ninety divided by ten", 9),
    ])
    func solvesPageQuestions(text: String, expected: Int) {
        #expect(MathSolver.solve(text, allowFiller: true) == expected)
    }
}

struct TextNormalizerTests {
    @Test(arguments: [
        ("UML A6", "UMLA6"), ("X5Y9A-", "X5Y9A"), ("Y7WGÄ", "Y7WGA"), ("в6з", "B63"), ("5 GK76=..", "5GK76"),
    ])
    func keepsOnlyAsciiLettersAndDigits(raw: String, expected: String) {
        #expect(TextNormalizer.normalize(raw) == expected)
    }
}

struct AnswerPickerTests {
    @Test func agreeingReadingsGiveOneAnswer() {
        #expect(AnswerPicker.pick(readings: ["TT 783", "TT783-"]) == .single("TT783"))
    }

    @Test func caseOnlyDifferenceKeepsFirstReading() {
        #expect(AnswerPicker.pick(readings: ["725WP", "725Wp."]) == .single("725WP"))
    }

    @Test func disagreementOffersBoth() {
        #expect(AnswerPicker.pick(readings: ["B63WG", "B63W6"]) == .choice(["B63WG", "B63W6"]))
    }

    @Test func emptyReadingIsIgnored() {
        #expect(AnswerPicker.pick(readings: ["", "DHDAT"]) == .single("DHDAT"))
    }

    @Test func nothingReadable() {
        #expect(AnswerPicker.pick(readings: ["", "--"]) == .none)
    }

    @Test func arithmeticIsSolved() {
        #expect(AnswerPicker.pick(readings: ["7 + 3 =", "7+3=?"]) == .single("10"))
    }
}
