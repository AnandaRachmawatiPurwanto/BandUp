import Foundation

public struct Word: Codable, Hashable, Sendable, Identifiable {
    public let word: String
    public let pos: String
    public let level: CEFRLevel

    public var id: String { "\(word.lowercased())|\(pos)" }

    public init(word: String, pos: String, level: CEFRLevel) {
        self.word = word
        self.pos = pos
        self.level = level
    }
}

/// The CEFR-labelled vocabulary (CEFR-J 1.5 for A1–B2, Octanove for C1–C2).
public struct WordBank: Sendable {
    public let words: [Word]
    private let lowestLevel: [String: CEFRLevel]
    private let byID: [String: Word]

    public init(words: [Word]) {
        self.words = words
        var lowest: [String: CEFRLevel] = [:]
        for w in words {
            let key = w.word.lowercased()
            if let existing = lowest[key], existing <= w.level { continue }
            lowest[key] = w.level
        }
        lowestLevel = lowest
        byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    public init(data: Data) throws {
        self.init(words: try JSONDecoder().decode([Word].self, from: data))
    }

    /// Loads the word list bundled with BandUpCore.
    public static func bundled() throws -> WordBank {
        guard let url = Bundle.module.url(forResource: "words", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try WordBank(data: Data(contentsOf: url))
    }

    /// The lowest level a surface form appears at, ignoring case.
    public func level(of form: String) -> CEFRLevel? {
        lowestLevel[form.lowercased()]
    }

    public func word(id: String) -> Word? { byID[id] }

    public func words(at level: CEFRLevel) -> [Word] {
        words.filter { $0.level == level }
    }
}
