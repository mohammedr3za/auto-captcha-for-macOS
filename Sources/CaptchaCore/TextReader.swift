import CoreImage
import Vision

public enum TextReader {
    private static let context = CIContext()

    /// OCR of the CAPTCHA after `ImageCleaner` (the more accurate reading, so first), then as
    /// captured, plus the cleaned image. Each reading gets right some CAPTCHAs the other
    /// misreads, and Vision's confidence is no help (it reports 1.0 on misreads too), so
    /// `AnswerPicker` compares them instead.
    public static func readings(of image: CGImage) -> (readings: [String], cleaned: CGImage?) {
        let source = CIImage(cgImage: image)
        let cleanedImage = ImageCleaner.clean(source)
        let cleaned = context.createCGImage(cleanedImage, from: cleanedImage.extent)
        let marginImage = ImageCleaner.withMargin(source, 20)
        let raw = context.createCGImage(marginImage, from: marginImage.extent).map(read) ?? ""
        return ((cleaned.map { [read($0)] } ?? []) + [raw], cleaned)
    }

    /// Recognized text with lines joined left to right; "" when nothing was found.
    public static func read(_ image: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Language correction turns random CAPTCHA strings into dictionary words.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return "" }
        return (request.results ?? [])
            .sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            .compactMap { $0.topCandidates(1).first?.string }
            .joined()
    }
}
