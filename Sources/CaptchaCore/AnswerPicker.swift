import Foundation

public enum Answer: Equatable {
    case single(String)
    /// The readings disagree; the user picks.
    case choice([String])
    case none
}

extension Answer {
    func uppercased() -> Answer {
        switch self {
        case .single(let text): .single(text.uppercased())
        case .choice(let options): .choice(options.map { $0.uppercased() })
        case .none: .none
        }
    }
}

public enum AnswerPicker {
    /// Combines several OCR readings of one CAPTCHA, most trusted first. Arithmetic is solved,
    /// readings that agree (ignoring case) collapse into one, and disagreements go to the user.
    public static func pick(readings: [String]) -> Answer {
        var candidates: [String] = []
        for reading in readings {
            let candidate = MathSolver.solve(reading, allowFiller: false).map(String.init)
                ?? TextNormalizer.normalize(reading)
            guard !candidate.isEmpty,
                  !candidates.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame })
            else { continue }
            candidates.append(candidate)
        }
        switch candidates.count {
        case 0: return .none
        case 1: return .single(candidates[0])
        default: return .choice(candidates)
        }
    }
}
