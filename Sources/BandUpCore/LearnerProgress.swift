import Foundation

public struct ReviewState: Codable, Hashable, Sendable {
    public var box: Int = 0
    public var due: Date
    public var correct: Int = 0
    public var wrong: Int = 0
}

/// One thing the learner did: answered a word, or got feedback on writing or speaking.
public struct PracticeEntry: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case word, writing, speaking }

    public var date: Date
    public var kind: Kind
    public var wordID: String?
    public var correct: Bool?
    /// Estimated overall band, for writing and speaking.
    public var band: Double?
}

/// Everything the learner has done, saved as one JSON file.
public struct LearnerProgress: Codable, Sendable {
    public var reviews: [String: ReviewState] = [:]
    public var streak: Int = 0
    public var lastPracticeDay: Date?
    public var targetLevel: CEFRLevel = .b2
    public var history: [PracticeEntry] = []

    public init() {}

    // Every key is optional so files saved by older versions still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reviews = try c.decodeIfPresent([String: ReviewState].self, forKey: .reviews) ?? [:]
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        lastPracticeDay = try c.decodeIfPresent(Date.self, forKey: .lastPracticeDay)
        targetLevel = try c.decodeIfPresent(CEFRLevel.self, forKey: .targetLevel) ?? .b2
        history = try c.decodeIfPresent([PracticeEntry].self, forKey: .history) ?? []
    }

    /// Records a writing or speaking session.
    public mutating func log(_ kind: PracticeEntry.Kind, band: Double, now: Date = .now) {
        history.append(PracticeEntry(date: now, kind: kind, band: band))
        markPracticed(now: now)
    }

    /// Days to wait after a correct answer, indexed by the new box (1...6).
    static let intervals: [Double] = [1, 3, 7, 14, 30, 60]
    /// A missed word comes back after this many hours.
    static let retryHours: Double = 4

    public mutating func record(_ wordID: String, correct: Bool, now: Date = .now) {
        var state = reviews[wordID] ?? ReviewState(due: now)
        if correct {
            state.box = min(state.box + 1, Self.intervals.count)
            state.correct += 1
            state.due = now.addingTimeInterval(Self.intervals[state.box - 1] * 86_400)
        } else {
            state.box = 0
            state.wrong += 1
            state.due = now.addingTimeInterval(Self.retryHours * 3_600)
        }
        reviews[wordID] = state
        history.append(PracticeEntry(date: now, kind: .word, wordID: wordID, correct: correct))
        markPracticed(now: now)
    }

    public mutating func markPracticed(now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        if let last = lastPracticeDay {
            let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            if gap == 0 { return }
            streak = gap == 1 ? streak + 1 : 1
        } else {
            streak = 1
        }
        lastPracticeDay = today
    }

    /// The streak as it stands today; a missed day shows as 0.
    public func currentStreak(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let last = lastPracticeDay else { return 0 }
        let gap = calendar.dateComponents([.day], from: last, to: calendar.startOfDay(for: now)).day ?? 0
        return gap <= 1 ? streak : 0
    }

    /// Picks the next words to ask: overdue reviews first, then new words at the target level.
    public func nextWords(_ count: Int, from bank: WordBank, now: Date = .now) -> [Word] {
        let due = reviews
            .filter { $0.value.due <= now }
            .sorted { $0.value.due < $1.value.due }
            .compactMap { bank.word(id: $0.key) }
        if due.count >= count { return Array(due.prefix(count)) }
        let fresh = bank.words(at: targetLevel)
            .filter { reviews[$0.id] == nil }
            .shuffled()
            .prefix(count - due.count)
        return due + fresh
    }

    public var learnedCount: Int { reviews.values.filter { $0.box >= 3 }.count }
}

/// Reads and writes LearnerProgress in Application Support.
public struct ProgressStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static func standard() -> ProgressStore {
        let dir = URL.applicationSupportDirectory.appending(path: "BandUp", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return ProgressStore(url: dir.appending(path: "progress.json"))
    }

    public func load() -> LearnerProgress {
        guard let data = try? Data(contentsOf: url),
              let progress = try? JSONDecoder().decode(LearnerProgress.self, from: data) else { return LearnerProgress() }
        return progress
    }

    public func save(_ progress: LearnerProgress) throws {
        try JSONEncoder().encode(progress).write(to: url, options: .atomic)
    }
}
