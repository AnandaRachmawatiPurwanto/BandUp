import BandUpCore
import SwiftUI

struct SpeakingView: View {
    @Environment(AppModel.self) private var model
    @State private var recorder = SpeechRecorder()
    @State private var prompt = Prompts.speaking.randomElement()!
    @State private var feedback: SpeakingFeedback?
    @State private var busy = false
    @State private var errorText: String?
    @State private var duration: TimeInterval = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Speaking \(prompt.part.rawValue)").font(.headline)
                    Text("· aim for about \(prompt.part.seconds) s").foregroundStyle(.secondary)
                    Spacer()
                    Button("New question", systemImage: "shuffle") { newQuestion() }
                        .buttonStyle(.borderless)
                        .disabled(recorder.isRecording)
                }
                Text(prompt.question)
                    .font(.title3)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

                recordControls

                if !recorder.transcript.isEmpty {
                    Text("What you said").font(.headline)
                    LevelColoredText(text: recorder.transcript, tagger: model.tagger)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    if !recorder.isRecording { stats }
                }

                if let text = recorder.errorText ?? errorText {
                    Text(text).foregroundStyle(.red)
                }

                if let fb = feedback { feedbackView(fb) }
            }
            .padding(20)
        }
    }

    private var recordControls: some View {
        HStack(spacing: 14) {
            Button {
                recorder.isRecording ? finish() : begin()
            } label: {
                Label(recorder.isRecording ? "Stop" : "Start speaking",
                      systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .tint(recorder.isRecording ? .red : .accentColor)
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])
            .disabled(busy)

            if recorder.isRecording, let start = recorder.startedAt {
                TimelineView(.periodic(from: start, by: 1)) { ctx in
                    let s = Int(ctx.date.timeIntervalSince(start))
                    Text(String(format: "%d:%02d", s / 60, s % 60))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(s >= prompt.part.seconds ? .orange : .primary)
                }
            }
            if busy { ProgressView().controlSize(.small); Text("Listening back…").foregroundStyle(.secondary) }
        }
    }

    /// Things we can measure ourselves, without the AI.
    private var stats: some View {
        let tokens = model.tagger.tag(recorder.transcript)
        let wpm = duration > 5 ? Double(tokens.count) / duration * 60 : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                Text("\(tokens.count) words")
                Text("\(Int(duration)) s")
                if wpm > 0 {
                    Text("\(Int(wpm)) words/min")
                        .foregroundStyle(wpm >= 110 ? .green : .orange)
                        .help("Fluent speakers are usually around 120–160 words per minute.")
                }
            }
            .font(.callout.monospacedDigit())
            LevelDistribution(summary: model.tagger.summary(of: tokens))
        }
    }

    private func feedbackView(_ fb: SpeakingFeedback) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text("Estimated band").font(.headline)
                Spacer()
                Text(fb.overall, format: .number.precision(.fractionLength(1)))
                    .font(.largeTitle.bold().monospacedDigit())
            }
            BandMeter(label: "Fluency & Coherence", band: fb.fluency)
            BandMeter(label: "Lexical Resource", band: fb.lexical)
            BandMeter(label: "Grammar", band: fb.grammar)
            Text("Judged from the transcript only, so pronunciation isn't scored. A rough guide, not an official score.")
                .font(.caption).foregroundStyle(.secondary)
            if !fb.answeredQuestion {
                Label("Your answer drifted from the question. Answer it directly first, then add a reason and an example.",
                      systemImage: "exclamationmark.bubble")
                    .foregroundStyle(.orange)
            }
            BulletList(title: "Next time", items: fb.tips, symbol: "arrow.up.right")
            if !fb.upgrades.isEmpty {
                Text("Word upgrades").font(.headline)
                UpgradeList(upgrades: fb.upgrades, tagger: model.tagger)
            }
        }
    }

    private func begin() {
        feedback = nil
        errorText = nil
        Task { await recorder.start() }
    }

    private func finish() {
        duration = recorder.startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        recorder.stop()
        busy = true
        Task {
            // Give the recognizer a moment to deliver its final words.
            try? await Task.sleep(for: .milliseconds(800))
            defer { busy = false }
            let transcript = recorder.transcript
            guard transcript.split(separator: " ").count >= 5 else {
                errorText = "That was very short. Try answering in at least two or three sentences."
                return
            }
            do {
                feedback = try await model.engine.review(answer: transcript, prompt: prompt)
                model.log(.speaking, band: feedback?.overall ?? 0)
            } catch {
                errorText = "Couldn't get feedback: \(error.localizedDescription)"
            }
        }
    }

    private func newQuestion() {
        prompt = Prompts.speaking.filter { $0 != prompt }.randomElement() ?? prompt
        feedback = nil
        errorText = nil
    }
}
