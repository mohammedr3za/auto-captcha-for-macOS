import Foundation
import ImageIO
import Testing
@testable import CaptchaCore

private func fixture(_ name: String) throws -> CGImage {
    let url = try #require(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "png"))
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
}

struct CaptchaSolverTests {
    @Test func agreeingOCRAnswersWithoutWaitingForTheModel() async throws {
        let image = try fixture("01_DHDAT")
        let start = ContinuousClock.now
        let result = await CaptchaSolver.solve(image, model: { _ in
            try await Task.sleep(for: .seconds(5))
            return "WRONG"
        })
        #expect(ContinuousClock.now - start < .seconds(2))
        #expect(result.answer == .single("DHDAT"))
        #expect(result.source == .ocr)
    }

    @Test func disagreeingOCRDefersToTheModel() async throws {
        // OCR reads this real CAPTCHA as L0415 and L045.
        let result = await CaptchaSolver.solve(try fixture("real/LO4J5"), model: { _ in "l04j5" })
        #expect(result.answer == .single("L04J5"))
        #expect(result.source == .model)
    }

    @Test func modelIsUsedWhenOCRIsNotTrusted() async throws {
        let result = await CaptchaSolver.solve(try fixture("01_DHDAT"), model: { _ in "DHDAT" }, trustAgreeingOCR: false)
        #expect(result.source == .model)
    }

    @Test func withoutAModelAgreeingOCRIsTyped() async throws {
        let result = await CaptchaSolver.solve(try fixture("01_DHDAT"), model: nil, trustAgreeingOCR: false)
        #expect(result.answer == .single("DHDAT"))
        #expect(result.source == .ocr)
    }

    @Test func withoutAModelDisagreeingOCRIsOffered() async throws {
        let result = await CaptchaSolver.solve(try fixture("real/LO4J5"), model: nil)
        #expect(result.source == .ocrFallback)
        #expect(result.answer == .choice(["L0415", "L045"]))
    }

    @Test func failingModelFallsBackToOCRReadings() async throws {
        struct OllamaDown: Error {}
        let result = await CaptchaSolver.solve(try fixture("real/LO4J5"), model: { _ in throw OllamaDown() })
        #expect(result.source == .ocrFallback)
        #expect(result.answer == .choice(["L0415", "L045"]))
    }
}
