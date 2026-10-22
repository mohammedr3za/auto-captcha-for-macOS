import CoreGraphics
import Foundation
import ImageIO

/// Reads CAPTCHAs with a vision-language model served by Ollama (https://ollama.com) on this Mac.
/// On 42 sample and real CAPTCHAs, qwen3.5:4b read 40 right where Vision OCR managed about three
/// in four; it copes with slanted and struck-through characters that OCR turns into 1, 7 or /.
public struct OllamaReader: Sendable {
    public static let defaultModel = "qwen3.5:4b"

    public var model: String
    public var endpoint: URL

    public init(model: String = defaultModel, endpoint: URL = URL(string: "http://localhost:11434")!) {
        self.model = model
        self.endpoint = endpoint
    }

    /// Asks for a transcription rather than an answer, so `MathSolver` does any arithmetic.
    static let prompt = """
        This image is a CAPTCHA. Transcribe the characters it shows, in order, ignoring the lines \
        and dots drawn over them. If it shows an arithmetic question, write the question with its \
        symbols, like 7+3=?. Reply with only that and nothing else.
        """

    public enum Failure: Error {
        case badImage
        case badResponse
    }

    /// Loads the model and keeps it in memory until `unload()`, so reads skip the ~3s load.
    /// Errors are left for `read` to report.
    public func warmUp() async {
        _ = try? await generate(["model": model, "stream": false, "keep_alive": -1], timeout: 60)
    }

    /// Frees the model's memory (about 4 GB for qwen3.5:4b). Blocks for up to a second, for use
    /// while quitting.
    public func unload() {
        guard let request = try? request(["model": model, "stream": false, "keep_alive": 0], timeout: 1) else {
            return
        }
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, _, _ in done.signal() }.resume()
        _ = done.wait(timeout: .now() + 1)
    }

    /// The model's transcription, in whatever case the model chose (it reads case poorly).
    /// Throws when Ollama isn't running, doesn't have the model, or replies with something that
    /// can't be a CAPTCHA answer.
    public func read(_ image: CGImage) async throws -> String {
        guard let png = Self.png(image) else { throw Failure.badImage }
        let reply = try await generate([
            "model": model,
            "prompt": Self.prompt,
            "images": [png.base64EncodedString()],
            "stream": false,
            "think": false,
            "keep_alive": -1,
            "options": ["temperature": 0, "num_predict": 16],
        ], timeout: 30)
        guard (1...24).contains(reply.count) else { throw Failure.badResponse }
        return reply
    }

    private func request(_ body: [String: Any], timeout: TimeInterval) throws -> URLRequest {
        var request = URLRequest(url: endpoint.appendingPathComponent("api/generate"), timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func generate(_ body: [String: Any], timeout: TimeInterval) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: request(body, timeout: timeout))
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String
        else { throw Failure.badResponse }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
