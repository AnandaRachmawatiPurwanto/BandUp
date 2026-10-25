import BandUpCore
import SwiftUI

@MainActor
@Observable
final class AppModel {
    let bank: WordBank
    let tagger: LevelTagger
    let engine: any FeedbackEngine = AppleFeedbackEngine()
    private let store = ProgressStore.standard()

    private(set) var progress: LearnerProgress
    /// The word shown in the quiz window.
    var quizWord: Word?
    var nextPing: Date?

    /// Set by the menu bar label, which is always alive, so notification taps can open windows.
    var openWindow: ((String) -> Void)?

    var pingsPerDay: Int {
        didSet { UserDefaults.standard.set(pingsPerDay, forKey: "pingsPerDay"); reschedule() }
    }
    var startHour: Int {
        didSet { UserDefaults.standard.set(startHour, forKey: "startHour"); reschedule() }
    }
    var endHour: Int {
        didSet { UserDefaults.standard.set(endHour, forKey: "endHour"); reschedule() }
    }

    var notifications: NotificationCoordinator!

    init() {
        bank = (try? WordBank.bundled()) ?? WordBank(words: [])
        tagger = LevelTagger(bank: bank)
        progress = store.load()
        let defaults = UserDefaults.standard
        pingsPerDay = defaults.object(forKey: "pingsPerDay") as? Int ?? 5
        startHour = defaults.object(forKey: "startHour") as? Int ?? 9
        endHour = defaults.object(forKey: "endHour") as? Int ?? 21
        notifications = NotificationCoordinator(model: self)
    }

    var targetLevel: CEFRLevel {
        get { progress.targetLevel }
        set { progress.targetLevel = newValue; save(); reschedule() }
    }

    var aiAvailable: Bool { AppleFeedbackEngine.isAvailable }

    func record(_ word: Word, correct: Bool) {
        progress.record(word.id, correct: correct)
        save()
    }

    func log(_ kind: PracticeEntry.Kind, band: Double) {
        progress.log(kind, band: band)
        save()
    }

    func nextQuizWord() -> Word? {
        progress.nextWords(1, from: bank).first
    }

    func open(_ window: String) {
        NSApp.activate()
        openWindow?(window)
    }

    func startQuiz(with word: Word? = nil) {
        quizWord = word ?? nextQuizWord()
        open("quiz")
    }

    @ObservationIgnored private var scheduling: Task<Void, Never>?

    /// Rebuilds the pop-up schedule. Calls in quick succession (launch, settings changes)
    /// collapse into one, so runs never overlap and pile up duplicate requests.
    func reschedule() {
        scheduling?.cancel()
        scheduling = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            nextPing = await notifications.schedule()
        }
    }

    private func save() {
        try? store.save(progress)
    }
}

extension CEFRLevel {
    /// One blue ramp, darker = harder (lighter on dark backgrounds), one step per A/B/C band.
    /// Validated as an ordinal ramp for both modes; the level text always sits beside it.
    var color: Color {
        let (light, dark): (UInt32, UInt32) = switch band {
        case "A": (0x86B6EF, 0x184F95)
        case "B": (0x2A78D6, 0x3987E5)
        default: (0x104281, 0x9EC5F4)
        }
        return ChartColors.dynamic(light: light, dark: dark)
    }
}

enum ChartColors {
    /// Categorical slots 1–2 of the reference palette, validated for both modes.
    static let writing = dynamic(light: 0x2A78D6, dark: 0x3987E5)
    static let speaking = dynamic(light: 0xEB6834, dark: 0xD95926)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}
