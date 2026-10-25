import BandUpCore
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("BandUp").font(.title2.bold())
                Spacer()
                Label("\(model.progress.currentStreak())", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.headline)
                    .help("Days in a row")
            }

            HStack {
                stat("\(model.progress.reviews.count)", "words seen")
                stat("\(model.progress.learnedCount)", "learned")
                stat(model.targetLevel.rawValue, "target")
            }

            if let next = model.nextPing {
                Text("Next pop-up around \(next.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !model.aiAvailable {
                Label("Turn on Apple Intelligence in System Settings for feedback.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }

            Divider()

            VStack(spacing: 8) {
                action("Quiz me now", "bolt.fill") { model.startQuiz() }
                action("Speaking practice", "mic.fill") { model.open("speaking") }
                action("Writing practice", "pencil.and.list.clipboard") { model.open("writing") }
                action("My progress", "chart.bar.xaxis") { model.open("summary") }
            }

            Divider()

            HStack {
                Button("Settings…") { NSApp.activate(); openSettings() }
                Button("Send test pop-up") { model.notifications.sendTestPing() }
                    .help("A word pop-up appears in 5 seconds")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func action(_ title: String, _ icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Picker("Target level", selection: $model.targetLevel) {
                ForEach(CEFRLevel.allCases, id: \.self) { level in
                    Text("\(level.rawValue)  (\(level.ieltsHint))").tag(level)
                }
            }
            Stepper("Pop-ups per day: \(model.pingsPerDay)", value: $model.pingsPerDay, in: 1...10)
            Picker("From", selection: $model.startHour) {
                ForEach(5..<model.endHour, id: \.self) { Text(hour($0)).tag($0) }
            }
            Picker("Until", selection: $model.endHour) {
                ForEach((model.startHour + 1)...24, id: \.self) { Text(hour($0)).tag($0) }
            }
            LabeledContent("Feedback engine", value: model.engine.name)
            Text("Word levels: CEFR-J Wordlist 1.5 (Tono Laboratory, TUFS) and Octanove Vocabulary Profile C1/C2 (CC BY-SA 4.0). Band estimates from the AI are rough guides, not official scores.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 440)
    }

    private func hour(_ h: Int) -> String { String(format: "%02d:00", h) }
}
