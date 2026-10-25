import Foundation
import NaturalLanguage

public struct TaggedToken: Hashable, Sendable {
    public let text: String
    public let range: Range<String.Index>
    /// Nil when the word is not in the list (names, numbers, rare words).
    public let level: CEFRLevel?
}

public struct LevelSummary: Sendable {
    public let counts: [CEFRLevel: Int]
    public let unknown: Int

    public var total: Int { counts.values.reduce(0, +) }

    /// Share of known words at B2 or above, 0...1.
    public var advancedShare: Double {
        guard total > 0 else { return 0 }
        let advanced = counts.filter { $0.key >= .b2 }.values.reduce(0, +)
        return Double(advanced) / Double(total)
    }
}

/// Labels every word of a text with its CEFR level.
public struct LevelTagger: Sendable {
    public let bank: WordBank

    public init(bank: WordBank) { self.bank = bank }

    public func tag(_ text: String) -> [TaggedToken] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var tokens: [TaggedToken] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma,
                             options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            let surface = String(text[range])
            guard surface.contains(where: \.isLetter) else { return true }
            let level = bank.level(of: surface) ?? tag.flatMap { bank.level(of: $0.rawValue) }
            tokens.append(TaggedToken(text: surface, range: range, level: level))
            return true
        }
        return tokens
    }

    public func summary(of tokens: [TaggedToken]) -> LevelSummary {
        var counts: [CEFRLevel: Int] = [:]
        var unknown = 0
        for t in tokens {
            if let level = t.level { counts[level, default: 0] += 1 } else { unknown += 1 }
        }
        return LevelSummary(counts: counts, unknown: unknown)
    }
}
