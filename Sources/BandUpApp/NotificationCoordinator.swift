import BandUpCore
import UserNotifications
import os

private let log = Logger(subsystem: "com.ananda.BandUp", category: "notifications")

/// Schedules the surprise pop-ups and handles answers typed straight into them.
@MainActor
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private unowned let model: AppModel
    private let center = UNUserNotificationCenter.current()

    static let quizCategory = "WORD_QUIZ"
    static let speakCategory = "SPEAK"
    static let answerAction = "ANSWER"
    static let showAction = "SHOW"
    private static let quizPrefix = "quiz-"
    private static let speakID = "speak-daily"

    init(model: AppModel) {
        self.model = model
        super.init()
        center.delegate = self
        let answer = UNTextInputNotificationAction(
            identifier: Self.answerAction, title: "Answer",
            textInputButtonTitle: "Check", textInputPlaceholder: "Write one sentence using the word…")
        let show = UNNotificationAction(identifier: Self.showAction, title: "I don't know — show me")
        let speak = UNNotificationAction(identifier: "OPEN_SPEAK", title: "Answer out loud", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.quizCategory, actions: [answer, show], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.speakCategory, actions: [speak], intentIdentifiers: []),
        ])
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces pending pop-ups with fresh ones for the rest of today and tomorrow.
    /// Returns the time of the next word pop-up.
    func schedule(now: Date = .now) async -> Date? {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier))

        let times = Self.pingTimes(count: model.pingsPerDay, start: model.startHour, end: model.endHour, now: now)
        let words = model.progress.nextWords(times.count, from: model.bank, now: now)
        for (time, word) in zip(times, words) {
            add(id: Self.quizPrefix + word.id, content: quizContent(for: word), at: time)
        }

        if let speakTime = Self.speakingTime(start: model.startHour, end: model.endHour, now: now),
           let prompt = Prompts.speaking.filter({ $0.part != .part2 }).randomElement() {
            let content = UNMutableNotificationContent()
            content.title = "Speaking · \(prompt.part.rawValue)"
            content.body = prompt.question
            content.sound = .default
            content.categoryIdentifier = Self.speakCategory
            add(id: Self.speakID, content: content, at: speakTime)
        }
        return times.first
    }

    /// Sends one word pop-up a few seconds from now, to try the flow without waiting.
    func sendTestPing() {
        guard let word = model.nextQuizWord() else { return }
        center.add(UNNotificationRequest(identifier: Self.quizPrefix + "test-" + word.id, content: quizContent(for: word),
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }

    private func quizContent(for word: Word) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(word.word)  ·  \(word.level.rawValue)"
        content.subtitle = word.pos
        content.body = "Use it in a sentence. Hover → Options → Answer."
        content.sound = .default
        content.categoryIdentifier = Self.quizCategory
        content.userInfo = ["wordID": word.id]
        return content
    }

    private func add(id: String, content: UNNotificationContent, at date: Date) {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Spreads `count` pings across the active hours, with some randomness so they feel like surprises.
    /// Covers the rest of today and all of tomorrow, so the app keeps pinging if it isn't reopened.
    nonisolated static func pingTimes(count: Int, start: Int, end: Int, now: Date,
                                      calendar: Calendar = .current) -> [Date] {
        guard count > 0, end > start else { return [] }
        let slot = Double(end - start) * 3_600 / Double(count)
        var times: [Date] = []
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)),
                  let open = calendar.date(bySettingHour: start, minute: 0, second: 0, of: day) else { continue }
            for i in 0..<count {
                let time = open.addingTimeInterval(slot * Double(i) + Double.random(in: 0.15...0.85) * slot)
                if time > now.addingTimeInterval(60) { times.append(time) }
            }
        }
        return times
    }

    nonisolated static func speakingTime(start: Int, end: Int, now: Date,
                                         calendar: Calendar = .current) -> Date? {
        // Late afternoon is a good moment to talk out loud; fall back to tomorrow.
        let hour = max(start, min(end - 1, 17))
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)),
                  let time = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) else { continue }
            if time > now { return time }
        }
        return nil
    }

    // MARK: - Delegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        let action = response.actionIdentifier
        let wordID = content.userInfo["wordID"] as? String
        let typed = (response as? UNTextInputNotificationResponse)?.userText
        log.notice("Notification response action=\(action, privacy: .public) cat=\(content.categoryIdentifier, privacy: .public) word=\(wordID ?? "nil", privacy: .public)")
        await handle(category: content.categoryIdentifier, action: action, wordID: wordID, typed: typed)
    }

    private func handle(category: String, action: String, wordID: String?, typed: String?) async {
        if category == Self.speakCategory {
            model.open("speaking")
            return
        }
        guard let wordID, let word = model.bank.word(id: wordID) else { return }

        switch action {
        case Self.answerAction:
            let sentence = typed?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            await answer(sentence, for: word)
        case Self.showAction:
            model.record(word, correct: false)
            await showMeaning(of: word)
        default:
            model.startQuiz(with: word)
        }
    }

    private func answer(_ sentence: String, for word: Word) async {
        guard !sentence.isEmpty, sentence != "?" else {
            model.record(word, correct: false)
            await showMeaning(of: word)
            return
        }
        let result = UNMutableNotificationContent()
        do {
            let check = try await model.engine.check(sentence: sentence, word: word)
            model.record(word, correct: check.isCorrect)
            result.title = check.isCorrect ? "✅ Nice — \(word.word)" : "✏️ Almost — \(word.word)"
            var lines = check.isCorrect ? [check.comment] : ["→ \(check.corrected)", check.comment]
            lines += check.otherUses.prefix(1).map { "Also: “\($0)”" }
            result.body = lines.joined(separator: "\n")
        } catch {
            log.error("Sentence check failed: \(String(describing: error), privacy: .public)")
            result.title = "Couldn't check that one"
            result.body = "Apple's AI couldn't check this sentence. Tap to try it in BandUp."
        }
        result.userInfo = ["wordID": word.id]
        post(result)
    }

    private func showMeaning(of word: Word) async {
        let result = UNMutableNotificationContent()
        result.title = "\(word.word)  ·  \(word.level.rawValue)"
        if let info = try? await model.engine.explain(word) {
            result.body = "\(info.definition)\n🇮🇩 \(info.indonesian)\n“\(info.example)”"
        } else {
            result.body = "Open BandUp to see this word."
        }
        result.userInfo = ["wordID": word.id]
        result.sound = nil
        post(result)
    }

    private func post(_ content: UNNotificationContent) {
        center.add(UNNotificationRequest(identifier: "result-\(UUID().uuidString)", content: content, trigger: nil)) { error in
            if let error { log.error("Couldn't post result: \(error.localizedDescription, privacy: .public)") }
        }
    }
}
