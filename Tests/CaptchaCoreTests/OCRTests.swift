import Foundation
import ImageIO
import Testing
@testable import CaptchaCore

struct OCRTests {
    /// Fixtures are generated CAPTCHAs styled like a real one (bold glyphs, five thin strike
    /// lines, colored speckles), named NN_ANSWER.png. Solved means the answer was typed outright
    /// or offered in the choice panel.
    @Test func solvesMostSampleCaptchas() throws {
        let directory = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" }
        var solved = 0
        var misses: [String] = []
        for url in files {
            let truth = String(url.deletingPathExtension().lastPathComponent.split(separator: "_")[1])
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let answer = AnswerPicker.pick(readings: TextReader.readings(of: image).readings)
            let offered: [String] = switch answer {
            case .single(let text): [text]
            case .choice(let options): options
            case .none: []
            }
            if offered.contains(where: { $0.caseInsensitiveCompare(truth) == .orderedSame }) {
                solved += 1
            } else {
                misses.append("\(truth) → \(offered)")
            }
        }
        #expect(files.count == 20)
        #expect(solved >= 18, "Missed: \(misses)")
    }

    /// Captured from a real login page by the app. The final 3 touches the right edge (the
    /// capture used to be inset by 2pt) and strike lines cross the second T.
    @Test func readsRealCaptchaOutright() throws {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/real/TT783", withExtension: "png"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(AnswerPicker.pick(readings: TextReader.readings(of: image).readings) == .single("TT783"))
    }
}
