import BandUpCore
import SwiftUI

enum Section: Hashable {
    case progress
    case lesson(String)
    case library
}

/// The main window: progress, study material and the word library in one sidebar.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @SceneStorage("section") private var storedSection = "progress"
    @State private var section: Section? = .progress

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                Label("Progress", systemImage: "chart.bar.xaxis").tag(Section.progress)
                Label("Word library", systemImage: "books.vertical").tag(Section.library)
                ForEach(LessonGroup.allCases, id: \.self) { group in
                    SwiftUI.Section(group.rawValue) {
                        ForEach(Lessons.lessons(in: group)) { lesson in
                            Text(lesson.title).tag(Section.lesson(lesson.id))
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            switch section {
            case .lesson(let id):
                if let lesson = Lessons.all.first(where: { $0.id == id }) { LessonView(lesson: lesson) }
            case .library:
                WordLibraryView()
            default:
                SummaryView()
            }
        }
        .onAppear { section = Self.decode(storedSection) }
        .onChange(of: section) { storedSection = Self.encode(section) }
    }

    private static func encode(_ section: Section?) -> String {
        switch section {
        case .lesson(let id): "lesson:" + id
        case .library: "library"
        default: "progress"
        }
    }

    private static func decode(_ raw: String) -> Section {
        if raw == "library" { return .library }
        if raw.hasPrefix("lesson:") { return .lesson(String(raw.dropFirst(7))) }
        return .progress
    }
}

struct LessonView: View {
    @Environment(AppModel.self) private var model
    let lesson: Lesson

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(lesson.group.rawValue.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(lesson.title).font(.largeTitle.bold())
                Text(lesson.summary).font(.title3).foregroundStyle(.secondary)
                Divider().padding(.vertical, 4)
                ForEach(Array(lesson.blocks.enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
                if let practice = lesson.practice {
                    Divider().padding(.vertical, 4)
                    practiceButton(practice)
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .textSelection(.enabled)
        }
        .defaultScrollAnchor(.top)
        .id(lesson.id)
        .navigationTitle(lesson.title)
    }

    @ViewBuilder private func view(for block: LessonBlock) -> some View {
        switch block {
        case .text(let text):
            Text(text).font(.body).lineSpacing(3)
        case .heading(let text):
            Text(text).font(.title3.bold()).padding(.top, 8)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(item)
                    }
                }
            }
        case .example(let label, let text):
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                LevelColoredText(text: text, tagger: model.tagger)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        case .phrases(let phrases):
            FlowPhrases(phrases: phrases, tagger: model.tagger)
        case .mistake(let wrong, let right, let why):
            VStack(alignment: .leading, spacing: 4) {
                Label(wrong, systemImage: "xmark").foregroundStyle(.secondary).strikethrough()
                Label(right, systemImage: "checkmark").fontWeight(.semibold)
                Text(why).font(.callout).foregroundStyle(.secondary).padding(.leading, 26)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder private func practiceButton(_ link: PracticeLink) -> some View {
        switch link {
        case .writing:
            Button("Practise writing now", systemImage: "pencil") { model.open("writing") }.buttonStyle(.borderedProminent)
        case .speaking:
            Button("Practise speaking now", systemImage: "mic.fill") { model.open("speaking") }.buttonStyle(.borderedProminent)
        case .quiz:
            Button("Quiz me on words", systemImage: "bolt.fill") { model.startQuiz() }.buttonStyle(.borderedProminent)
        }
    }
}

/// Phrases as chips with their CEFR level. A multi-word phrase only gets a level when the
/// list has the phrase itself: its words' levels ("hand" is A1) say nothing about "on the other hand".
private struct FlowPhrases: View {
    let phrases: [String]
    let tagger: LevelTagger

    private func level(of phrase: String) -> CEFRLevel? {
        let tokens = tagger.tag(phrase)
        return tokens.count == 1 ? tokens[0].level : tagger.bank.level(of: phrase)
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(phrases, id: \.self) { phrase in
                HStack(spacing: 6) {
                    Text(phrase).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    if let level = level(of: phrase) { LevelBadge(level: level) }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct WordLibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var level: CEFRLevel? = nil
    @State private var filter = Filter.all
    @State private var query = ""
    @State private var selected: Word.ID?
    @State private var explanations: [Word.ID: WordExplanation] = [:]
    @State private var loading: Word.ID?

    enum Filter: String, CaseIterable { case all = "All", seen = "Seen", learned = "Learned", toReview = "Missed" }

    private var words: [Word] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return model.bank.words.filter { w in
            (level == nil || w.level == level)
                && (q.isEmpty || w.word.lowercased().hasPrefix(q))
                && matches(w)
        }
    }

    private func matches(_ w: Word) -> Bool {
        let state = model.progress.reviews[w.id]
        switch filter {
        case .all: return true
        case .seen: return state != nil
        case .learned: return (state?.box ?? 0) >= 3
        case .toReview: return (state?.wrong ?? 0) > 0 && state?.box == 0
        }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Picker("Level", selection: $level) {
                        Text("All levels").tag(CEFRLevel?.none)
                        ForEach(CEFRLevel.allCases, id: \.self) { Text($0.rawValue).tag(CEFRLevel?.some($0)) }
                    }
                    .frame(width: 140)
                    Picker("Show", selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .labelsHidden()
                .padding(10)
                let list = words
                Table(list, selection: $selected) {
                    TableColumn("Word") { w in Text(w.word).fontWeight(.medium) }
                    TableColumn("Level") { w in LevelBadge(level: w.level) }.width(56)
                    TableColumn("Type") { w in Text(w.pos).foregroundStyle(.secondary) }.width(90)
                    TableColumn("Status") { w in status(w) }.width(80)
                }
                Text("\(list.count) words").font(.caption).foregroundStyle(.secondary).padding(6)
            }
            .frame(minWidth: 420)

            detail.frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        }
        .searchable(text: $query, prompt: "Search words")
        .navigationTitle("Word library")
    }

    @ViewBuilder private func status(_ w: Word) -> some View {
        if let state = model.progress.reviews[w.id] {
            if state.box >= 3 { Label("Learned", systemImage: "checkmark.seal.fill").labelStyle(.iconOnly).foregroundStyle(.green).help("Learned") }
            else if state.box == 0 && state.wrong > 0 { Text("missed \(state.wrong)×").font(.caption).foregroundStyle(.orange) }
            else { Text("seen").font(.caption).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private var detail: some View {
        if let id = selected, let word = model.bank.word(id: id) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(word.word).font(.system(size: 32, weight: .bold, design: .serif))
                        LevelBadge(level: word.level)
                    }
                    Text("\(word.pos) · \(word.level.ieltsHint)").foregroundStyle(.secondary)
                    if let info = explanations[id] {
                        Text(info.definition).font(.headline)
                        Text("🇮🇩 \(info.indonesian)")
                        Text("“\(info.example)”").italic().foregroundStyle(.secondary)
                    } else if loading == id {
                        ProgressView("Asking Apple Intelligence…").controlSize(.small)
                    } else {
                        Button("Explain this word", systemImage: "text.book.closed") { explain(word) }
                    }
                    Button("Practise this word", systemImage: "bolt.fill") { model.startQuiz(with: word) }
                        .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Select a word to see what it means.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func explain(_ word: Word) {
        loading = word.id
        Task {
            defer { loading = nil }
            if let info = try? await model.engine.explain(word) { explanations[word.id] = info }
        }
    }
}
