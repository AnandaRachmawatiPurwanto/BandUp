import Foundation
import Testing
@testable import BandUpCore

@Suite struct WordBankTests {
    let bank = try! WordBank.bundled()

    @Test func loadsAllLevels() {
        #expect(bank.words.count > 9_000)
        for level in CEFRLevel.allCases { #expect(!bank.words(at: level).isEmpty) }
    }

    @Test func splitsVariantSpellings() {
        #expect(bank.level(of: "analyze") == bank.level(of: "analyse"))
        #expect(bank.level(of: "analyse") != nil)
    }

    @Test func usesLowestLevelAcrossPartsOfSpeech() {
        #expect(bank.level(of: "a") == .a1)
        #expect(bank.level(of: "ABANDON") == .b1)
    }
}

@Suite struct LevelTaggerTests {
    let tagger = LevelTagger(bank: try! WordBank.bundled())

    @Test func tagsInflectedFormsThroughTheLemma() {
        let tokens = tagger.tag("She abandoned the plans.")
        #expect(tokens.map(\.text) == ["She", "abandoned", "the", "plans"])
        #expect(tokens[1].level != nil)
    }

    @Test func leavesUnknownWordsUnlabelled() {
        let tokens = tagger.tag("Zxqv went home.")
        #expect(tokens.first?.level == nil)
        #expect(tagger.summary(of: tokens).unknown == 1)
    }

    @Test func skipsNumbersAndPunctuation() {
        #expect(tagger.tag("In 2024, 50% rose!").map(\.text) == ["In", "rose"])
    }
}

@Suite struct ProgressTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let cal = Calendar(identifier: .gregorian)

    @Test func correctAnswersSpaceOutReviews() {
        var p = LearnerProgress()
        p.record("w", correct: true, now: start)
        #expect(p.reviews["w"]?.box == 1)
        #expect(p.reviews["w"]?.due == start.addingTimeInterval(86_400))
        p.record("w", correct: true, now: start)
        #expect(p.reviews["w"]?.due == start.addingTimeInterval(3 * 86_400))
    }

    @Test func wrongAnswerResetsAndRetriesSoon() {
        var p = LearnerProgress()
        p.record("w", correct: true, now: start)
        p.record("w", correct: false, now: start)
        #expect(p.reviews["w"]?.box == 0)
        #expect(p.reviews["w"]?.due == start.addingTimeInterval(4 * 3_600))
    }

    @Test func streakCountsConsecutiveDays() {
        var p = LearnerProgress()
        p.markPracticed(now: start, calendar: cal)
        p.markPracticed(now: start, calendar: cal)
        #expect(p.streak == 1)
        p.markPracticed(now: start.addingTimeInterval(86_400), calendar: cal)
        #expect(p.streak == 2)
        #expect(p.currentStreak(now: start.addingTimeInterval(3 * 86_400), calendar: cal) == 0)
        p.markPracticed(now: start.addingTimeInterval(3 * 86_400), calendar: cal)
        #expect(p.streak == 1)
    }

    @Test func dueReviewsComeBeforeNewWords() throws {
        let bank = try WordBank.bundled()
        var p = LearnerProgress()
        let old = bank.words(at: .a1)[0]
        p.record(old.id, correct: false, now: start)
        let picks = p.nextWords(3, from: bank, now: start.addingTimeInterval(5 * 3_600))
        #expect(picks.first == old)
        #expect(picks.dropFirst().allSatisfy { $0.level == p.targetLevel })
    }

    @Test func roundsOverallToHalfBand() {
        #expect(roundToHalf(6.125) == 6.0)
        #expect(roundToHalf(6.25) == 6.5)
        #expect(roundToHalf(6.75) == 7.0)
    }
}

@Suite struct SummaryTests {
    let bank = try! WordBank.bundled()
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let cal = Calendar(identifier: .gregorian)

    @Test func loadsFilesSavedBeforeHistoryExisted() throws {
        let old = #"{"reviews":{},"streak":3,"targetLevel":"C1"}"#
        let p = try JSONDecoder().decode(LearnerProgress.self, from: Data(old.utf8))
        #expect(p.streak == 3)
        #expect(p.targetLevel == .c1)
        #expect(p.history.isEmpty)
    }

    @Test func countsSeenAndLearnedPerLevel() {
        var p = LearnerProgress()
        let w = bank.words(at: .b2)[0]
        for _ in 0..<3 { p.record(w.id, correct: true, now: start) }
        p.record(bank.words(at: .b2)[1].id, correct: false, now: start)
        let b2 = p.levelCounts(in: bank).first { $0.level == .b2 }!
        #expect(b2.seen == 2)
        #expect(b2.learned == 1)
    }

    @Test func listsStrugglingWordsWorstFirst() {
        var p = LearnerProgress()
        let a = bank.words(at: .b1)[0], b = bank.words(at: .b1)[1], ok = bank.words(at: .b1)[2]
        p.record(a.id, correct: false, now: start)
        p.record(b.id, correct: false, now: start)
        p.record(b.id, correct: false, now: start)
        p.record(ok.id, correct: true, now: start)
        let s = p.struggling(in: bank)
        #expect(s.map(\.word) == [b, a])
    }

    @Test func activityCoversEachDayOldestFirst() {
        var p = LearnerProgress()
        p.record("x", correct: true, now: start)
        p.log(.writing, band: 6, now: start)
        let days = p.activity(days: 3, now: start.addingTimeInterval(86_400), calendar: cal)
        #expect(days.count == 3)
        #expect(days[1].words == 1 && days[1].sessions == 1)
        #expect(days[2].words == 0)
    }

    @Test func accuracyUsesRecentAnswersOnly() {
        var p = LearnerProgress()
        p.record("old", correct: false, now: start)
        p.record("a", correct: true, now: start.addingTimeInterval(10 * 86_400))
        p.record("b", correct: false, now: start.addingTimeInterval(10 * 86_400))
        #expect(p.accuracy(now: start.addingTimeInterval(10 * 86_400)) == 0.5)
        #expect(LearnerProgress().accuracy() == nil)
    }
}

@Suite struct LessonTests {
    @Test func everyGroupHasLessonsAndIDsAreUnique() {
        for group in LessonGroup.allCases { #expect(!Lessons.lessons(in: group).isEmpty) }
        #expect(Set(Lessons.all.map(\.id)).count == Lessons.all.count)
    }

    @Test func singleWordPhrasesInLessonsHaveALevel() {
        let tagger = LevelTagger(bank: try! WordBank.bundled())
        for lesson in Lessons.all {
            for case .phrases(let list) in lesson.blocks {
                for phrase in list where tagger.tag(phrase).count == 1 {
                    #expect(tagger.tag(phrase)[0].level != nil, "\(lesson.id): \(phrase) has no level")
                }
            }
        }
    }
}
