import BandUpCore
import SwiftUI

struct WritingView: View {
    @Environment(AppModel.self) private var model
    @State private var prompt = Prompts.writing.randomElement()!
    @State private var essay = ""
    @State private var feedback: EssayFeedback?
    @State private var busy = false
    @State private var errorText: String?
    @State private var startedAt = Date.now

    private var wordCount: Int { model.tagger.tag(essay).count }

    var body: some View {
        HSplitView {
            editor.frame(minWidth: 420)
            review.frame(minWidth: 340)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Writing \(prompt.task)").font(.headline)
                Spacer()
                Button("New question", systemImage: "shuffle") { newQuestion() }
                    .buttonStyle(.borderless)
            }
            Text(prompt.question)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            TextEditor(text: $essay)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))

            HStack {
                Text("\(wordCount) / \(prompt.minWords) words")
                    .foregroundStyle(wordCount >= prompt.minWords ? .green : .secondary)
                TimelineView(.periodic(from: startedAt, by: 1)) { ctx in
                    let minutes = Int(ctx.date.timeIntervalSince(startedAt)) / 60
                    Text("· \(minutes) min (exam: 40)").foregroundStyle(minutes >= 40 ? .orange : .secondary)
                }
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button("Get feedback") { submit() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(wordCount < 50 || busy)
            }
            .font(.callout.monospacedDigit())
        }
        .padding(16)
    }

    private var review: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your vocabulary").font(.headline)
                LevelDistribution(summary: model.tagger.summary(of: model.tagger.tag(essay)))
                if !essay.isEmpty {
                    LevelColoredText(text: essay, tagger: model.tagger)
                        .font(.callout)
                        .padding(10)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    Text("B1 and up are coloured; C-level words are bold.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let errorText { Text(errorText).foregroundStyle(.red) }

                if let fb = feedback {
                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        Text("Estimated band").font(.headline)
                        Spacer()
                        Text(fb.overall, format: .number.precision(.fractionLength(1)))
                            .font(.largeTitle.bold().monospacedDigit())
                    }
                    BandMeter(label: "Task Response", band: fb.taskResponse)
                    BandMeter(label: "Coherence & Cohesion", band: fb.coherence)
                    BandMeter(label: "Lexical Resource", band: fb.lexical)
                    BandMeter(label: "Grammar", band: fb.grammar)
                    Text("A rough on-device estimate, not an official score.")
                        .font(.caption).foregroundStyle(.secondary)
                    BulletList(title: "What works", items: fb.strengths, symbol: "checkmark")
                    BulletList(title: "Do this next", items: fb.improvements, symbol: "arrow.up.right")
                    if !fb.upgrades.isEmpty {
                        Text("Word upgrades").font(.headline)
                        UpgradeList(upgrades: fb.upgrades, tagger: model.tagger)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func submit() {
        busy = true
        errorText = nil
        let text = essay
        Task {
            defer { busy = false }
            do {
                feedback = try await model.engine.review(essay: text, prompt: prompt)
                model.log(.writing, band: feedback?.overall ?? 0)
            } catch {
                errorText = "Couldn't get feedback: \(error.localizedDescription)"
            }
        }
    }

    private func newQuestion() {
        prompt = Prompts.writing.filter { $0 != prompt }.randomElement() ?? prompt
        essay = ""
        feedback = nil
        startedAt = .now
    }
}
