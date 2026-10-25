import Foundation

public struct LevelCount: Hashable, Sendable {
    public let level: CEFRLevel
    public let seen: Int
    public let learned: Int
}

public struct DayCount: Hashable, Sendable {
    public let day: Date
    public let words: Int
    public let sessions: Int
}

public struct BandPoint: Hashable, Sendable {
    public let date: Date
    public let kind: PracticeEntry.Kind
    public let band: Double
}

/// Numbers for the summary window.
extension LearnerProgress {
    /// Words seen and learned (reached box 3, about a week of spacing) per level.
    public func levelCounts(in bank: WordBank) -> [LevelCount] {
        var seen: [CEFRLevel: Int] = [:]
        var learned: [CEFRLevel: Int] = [:]
        for (id, state) in reviews {
            guard let level = bank.word(id: id)?.level else { continue }
            seen[level, default: 0] += 1
            if state.box >= 3 { learned[level, default: 0] += 1 }
        }
        return CEFRLevel.allCases.map {
            LevelCount(level: $0, seen: seen[$0, default: 0], learned: learned[$0, default: 0])
        }
    }

    public func dueCount(now: Date = .now) -> Int {
        reviews.values.filter { $0.due <= now }.count
    }

    /// Words missed more than once, or missed and not yet recovered, worst first.
    public func struggling(in bank: WordBank, limit: Int = 8) -> [(word: Word, wrong: Int)] {
        reviews
            .filter { $0.value.wrong >= 2 || ($0.value.wrong > 0 && $0.value.box == 0) }
            .sorted { ($0.value.wrong, $1.value.box) > ($1.value.wrong, $0.value.box) }
            .prefix(limit)
            .compactMap { id, state in bank.word(id: id).map { ($0, state.wrong) } }
    }

    /// Activity per day for the last `days` days, oldest first.
    public func activity(days: Int, now: Date = .now, calendar: Calendar = .current) -> [DayCount] {
        let today = calendar.startOfDay(for: now)
        var words: [Date: Int] = [:]
        var sessions: [Date: Int] = [:]
        for entry in history {
            let day = calendar.startOfDay(for: entry.date)
            if entry.kind == .word { words[day, default: 0] += 1 } else { sessions[day, default: 0] += 1 }
        }
        return (0..<days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map {
                DayCount(day: $0, words: words[$0, default: 0], sessions: sessions[$0, default: 0])
            }
        }
    }

    public func bandHistory() -> [BandPoint] {
        history.compactMap { e in e.band.map { BandPoint(date: e.date, kind: e.kind, band: $0) } }
    }

    /// Share of word answers that were right over the last `days` days, or nil if none.
    public func accuracy(days: Int = 7, now: Date = .now) -> Double? {
        let since = now.addingTimeInterval(-Double(days) * 86_400)
        let answers = history.filter { $0.kind == .word && $0.date >= since }.compactMap(\.correct)
        guard !answers.isEmpty else { return nil }
        return Double(answers.filter { $0 }.count) / Double(answers.count)
    }
}
