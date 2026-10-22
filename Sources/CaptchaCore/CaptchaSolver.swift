import CoreGraphics
import Foundation

/// Reads a CAPTCHA image as fast as accuracy allows. Vision OCR takes well under a second and is
/// trusted when its two readings agree, which they did on 28 of 42 test CAPTCHAs, wrongly only
/// once. Otherwise the answer comes from the model (about 1.4s), which is started alongside OCR.
public enum CaptchaSolver {
    public enum Source {
        /// Vision OCR's two readings agreed.
        case ocr
        case model
        /// There was no model, or it failed (usually because Ollama isn't running), so OCR's
        /// readings are used as-is.
        case ocrFallback
    }

    public struct Result {
        public var answer: Answer
        public var source: Source
        /// The cleaned-up image OCR read, for checking misreads.
        public var cleaned: CGImage?
    }

    /// - Parameters:
    ///   - model: reads the image with the model, or nil to use OCR alone. Started at once, and
    ///     cancelled if OCR settles it.
    ///   - trustAgreeingOCR: false always waits for the model, when there is one.
    ///   - uppercased: type answers in capitals; the model reads case poorly and most CAPTCHAs ignore it.
    ///   - willWaitForModel: called when OCR didn't settle it, before waiting on the model.
    public static func solve(
        _ image: CGImage,
        model: (@Sendable (CGImage) async throws -> String)?,
        trustAgreeingOCR: Bool = true,
        uppercased: Bool = true,
        willWaitForModel: @MainActor () -> Void = {}
    ) async -> Result {
        let modelTask = model.map { read in Task { try await read(image) } }
        let ocr = await Task.detached { TextReader.readings(of: image) }.value
        let ocrAnswer = AnswerPicker.pick(readings: ocr.readings)
        let ocrAgrees = ocr.readings.count >= 2
            && ocr.readings.allSatisfy { !TextNormalizer.normalize($0).isEmpty }
            && { if case .single = ocrAnswer { true } else { false } }()

        var result: Result
        if ocrAgrees && (trustAgreeingOCR || modelTask == nil) {
            modelTask?.cancel()
            result = Result(answer: ocrAnswer, source: .ocr, cleaned: ocr.cleaned)
        } else if let modelTask {
            await willWaitForModel()
            if let reading = try? await modelTask.value {
                result = Result(answer: AnswerPicker.pick(readings: [reading]), source: .model, cleaned: ocr.cleaned)
            } else {
                result = Result(answer: ocrAnswer, source: .ocrFallback, cleaned: ocr.cleaned)
            }
        } else {
            result = Result(answer: ocrAnswer, source: .ocrFallback, cleaned: ocr.cleaned)
        }
        if uppercased { result.answer = result.answer.uppercased() }
        return result
    }
}
