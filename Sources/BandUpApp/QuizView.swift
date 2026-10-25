import BandUpCore
import SwiftUI

struct QuizView: View {
    @Environment(AppModel.self) private var model
    @State private var sentence = ""
    @State private var check: SentenceCheck?
    @State private var explanation: WordExplanation?
    @State private var busy = false
    @State private var errorText: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let word = model.quizWord {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(word.word).font(.system(size: 38, weight: .bold, design: .serif))
                    LevelBadge(level: word.level)
                    Text(word.pos).foregroundStyle(.secondary)
                }
                Text("Write one sentence using this word.")
                    .foregroundStyle(.secondary)

                TextField("Your sentence…", text: $sentence, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit { submit(word) }
                    .disabled(check != nil || explanation != nil)

                HStack {
                    if check == nil && explanation == nil {
                        Button("Check") { submit(word) }
                            .keyboardShortcut(.defaultAction)
                            .disabled(sentence.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                        Button("I don't know") { reveal(word) }.disabled(busy)
                    } else {
                        Button("Next word") { next() }.keyboardShortcut(.defaultAction)
                    }
                    if busy { ProgressView().controlSize(.small) }
                }

                if let check { result(check) }
                if let explanation { meaning(explanation) }
                if let errorText { Text(errorText).foregroundStyle(.red).font(.callout) }
            } else {
                Text("No word to practise right now.")
                Button("Get a word") { next() }
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            if model.quizWord == nil { model.quizWord = model.nextQuizWord() }
            focused = true
        }
        .onChange(of: model.quizWord) { reset() }
    }

    private func result(_ check: SentenceCheck) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(check.isCorrect ? "Nice!" : "Almost", systemImage: check.isCorrect ? "checkmark.circle.fill" : "pencil.circle.fill")
                .font(.headline)
                .foregroundStyle(check.isCorrect ? .green : .orange)
            if !check.isCorrect {
                Text("Your sentence, fixed:").font(.caption).foregroundStyle(.secondary)
                LevelColoredText(text: check.corrected, tagger: model.tagger)
            }
            Text(check.comment).foregroundStyle(.secondary)
            if !check.otherUses.isEmpty {
                Text("Other ways to use it").font(.caption.weight(.semibold)).padding(.top, 4)
                ForEach(check.otherUses, id: \.self) { Text("• \($0)").italic() }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func meaning(_ info: WordExplanation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(info.definition).font(.headline)
            Text("🇮🇩 \(info.indonesian)")
            Text("“\(info.example)”").italic().foregroundStyle(.secondary)
            Text("This word will come back in a few hours.").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func submit(_ word: Word) {
        let text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        busy = true
        errorText = nil
        Task {
            defer { busy = false }
            do {
                let result = try await model.engine.check(sentence: text, word: word)
                check = result
                model.record(word, correct: result.isCorrect)
                if !result.isCorrect { explanation = try? await model.engine.explain(word) }
            } catch {
                errorText = "Couldn't reach Apple Intelligence: \(error.localizedDescription)"
            }
        }
    }

    private func reveal(_ word: Word) {
        busy = true
        errorText = nil
        model.record(word, correct: false)
        Task {
            defer { busy = false }
            do { explanation = try await model.engine.explain(word) }
            catch { errorText = "Couldn't reach Apple Intelligence: \(error.localizedDescription)" }
        }
    }

    private func next() {
        model.quizWord = model.nextQuizWord()
    }

    private func reset() {
        sentence = ""
        check = nil
        explanation = nil
        errorText = nil
        focused = true
    }
}
