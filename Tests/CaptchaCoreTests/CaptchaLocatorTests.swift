import CoreGraphics
import Testing
@testable import CaptchaCore

private func field(_ label: String = "", y: CGFloat) -> PageNode {
    PageNode(kind: .textField, label: label, frame: CGRect(x: 100, y: y, width: 200, height: 30))
}

private func text(_ text: String, y: CGFloat) -> PageNode {
    PageNode(kind: .text, text: text, frame: CGRect(x: 100, y: y, width: 200, height: 18))
}

private func image(_ label: String = "", y: CGFloat) -> PageNode {
    PageNode(kind: .image, label: label, frame: CGRect(x: 100, y: y, width: 180, height: 60))
}

struct CaptchaLocatorTests {
    @Test func findsLabelledFieldAndAdjacentImage() {
        let nodes = [text("Email", y: 80), field("email", y: 100), image(y: 150), field("Enter captcha", y: 220)]
        let target = CaptchaLocator.locate(in: nodes)
        #expect(target?.fieldIndex == 3)
        #expect(target?.imageFrame == nodes[2].frame)
    }

    @Test func prefersFieldRightAfterCaptchaWording() {
        // A login form: the other fields are near the CAPTCHA too, but less so.
        let nodes = [
            text("Username", y: 0), field(y: 20), text("Password", y: 60), field(y: 80),
            image(y: 130), text("Enter the characters shown above", y: 200), field(y: 220),
        ]
        #expect(CaptchaLocator.locate(in: nodes)?.fieldIndex == 6)
    }

    @Test func solvesTextQuestionInsteadOfReadingAnImage() {
        let nodes = [text("What is 7 + 5?", y: 100), field("answer", y: 120)]
        let target = CaptchaLocator.locate(in: nodes)
        #expect(target?.fieldIndex == 1)
        #expect(target?.question == "What is 7 + 5?")
        #expect(target?.imageFrame == nil)
    }

    @Test func ignoresOrdinaryForms() {
        let nodes = [text("Name", y: 0), field("name", y: 20), text("Phone: 1-800-555-1234", y: 60), field("phone", y: 80)]
        #expect(CaptchaLocator.locate(in: nodes) == nil)
    }

    @Test func labelledFieldWithoutImageStillTargetsField() {
        let target = CaptchaLocator.locate(in: [field("captcha_code", y: 100)])
        #expect(target == CaptchaTarget(fieldIndex: 0, imageFrame: nil, question: nil))
    }

    @Test func captchaAltTextFindsUnlabelledField() {
        let nodes = [image("Security code", y: 100), field(y: 170)]
        #expect(CaptchaLocator.locate(in: nodes)?.imageFrame == nodes[0].frame)
    }
}
