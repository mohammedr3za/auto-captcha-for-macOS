import Foundation
import ImageIO
import Testing
@testable import CaptchaCore

private let ollamaIsRunning = (try? Data(contentsOf: URL(string: "http://localhost:11434/api/version")!)) != nil

/// Needs Ollama running locally with `OllamaReader.defaultModel` pulled.
@Suite(.enabled(if: ollamaIsRunning, "Ollama isn't running on localhost:11434"))
struct OllamaReaderTests {
    /// Real CAPTCHAs from a login page, both misread by Vision OCR. In LO4J5's font the letter
    /// O and the digit 0 look alike, so either is accepted.
    @Test(arguments: [("TT783", ["TT783"]), ("LO4J5", ["LO4J5", "L04J5"])])
    func readsRealCaptchas(name: String, accepted: [String]) async throws {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/real/\(name)", withExtension: "png"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let answer = AnswerPicker.pick(readings: [try await OllamaReader().read(image)])
        #expect(accepted.map(Answer.single).contains(answer))
    }
}
