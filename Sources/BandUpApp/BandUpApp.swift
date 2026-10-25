import BandUpCore
import SwiftUI

@main
struct BandUpApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        // The first scene opens at launch and when the Dock icon is clicked.
        Window("BandUp", id: "summary") {
            MainView().environment(model)
        }
        .defaultSize(width: 1100, height: 760)

        MenuBarExtra {
            MenuBarView()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Word Quiz", id: "quiz") {
            QuizView().environment(model)
        }
        .windowResizability(.contentSize)

        Window("Writing", id: "writing") {
            WritingView().environment(model)
        }
        .defaultSize(width: 900, height: 700)

        Window("Speaking", id: "speaking") {
            SpeakingView().environment(model)
        }
        .defaultSize(width: 720, height: 640)

        Settings {
            SettingsView().environment(model)
        }
    }
}

/// The menu bar icon. It lives as long as the app, so it hands `openWindow`
/// to the model and kicks off the first schedule.
private struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "character.book.closed.fill")
            .task {
                model.openWindow = { openWindow(id: $0) }
                if await model.notifications.requestPermission() {
                    model.reschedule()
                }
            }
    }
}

struct LevelBadge: View {
    let level: CEFRLevel

    var body: some View {
        Text(level.rawValue)
            .font(.caption.weight(.bold).monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.color.opacity(0.28), in: Capsule())
            .foregroundStyle(.primary)
    }
}

struct BandMeter: View {
    let label: String
    let band: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.callout)
                Spacer()
                Text(band, format: .number.precision(.fractionLength(1)))
                    .font(.callout.monospacedDigit().weight(.semibold))
            }
            ProgressView(value: band, total: 9)
                .tint(band >= 7 ? .green : band >= 5.5 ? .blue : .orange)
        }
    }
}

/// Colours each word of a text by its CEFR level.
struct LevelColoredText: View {
    let text: String
    let tagger: LevelTagger

    var body: some View {
        Text(attributed).textSelection(.enabled)
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        for token in tagger.tag(text) {
            guard let level = token.level, level >= .b1,
                  let range = Range(token.range, in: result) else { continue }
            result[range].foregroundColor = level.color
            if level >= .c1 { result[range].font = .body.bold() }
        }
        return result
    }
}

/// Share of A, B and C words in a text, as one stacked bar.
struct LevelDistribution: View {
    let summary: LevelSummary

    private static let bands: [(name: String, levels: [CEFRLevel])] = [
        ("A", [.a1, .a2]), ("B", [.b1, .b2]), ("C", [.c1, .c2]),
    ]

    private func count(_ levels: [CEFRLevel]) -> Int {
        levels.reduce(0) { $0 + summary.counts[$1, default: 0] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Self.bands, id: \.name) { band in
                        let n = count(band.levels)
                        if n > 0 {
                            band.levels[0].color
                                .frame(width: max(0, (geo.size.width - 4) * CGFloat(n) / CGFloat(max(summary.total, 1))))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .help("\(band.name): \(n) words")
                        }
                    }
                }
            }
            .frame(height: 10)
            HStack(spacing: 12) {
                ForEach(Self.bands, id: \.name) { band in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(band.levels[0].color).frame(width: 9, height: 9)
                        Text("\(band.name) \(count(band.levels))")
                    }
                }
                Spacer()
                Text("B2+ \(Int((summary.advancedShare * 100).rounded()))%").bold()
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}

struct UpgradeList: View {
    let upgrades: [WordUpgrade]
    let tagger: LevelTagger

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(upgrades, id: \.self) { up in
                HStack(spacing: 6) {
                    Text(up.original).strikethrough().foregroundStyle(.secondary)
                    level(of: up.original)
                    Image(systemName: "arrow.right").font(.caption)
                    Text(up.better).bold()
                    level(of: up.better)
                }
            }
        }
    }

    /// The highest level among the words of a phrase.
    @ViewBuilder private func level(of phrase: String) -> some View {
        if let top = tagger.tag(phrase).compactMap(\.level).max() { LevelBadge(level: top) }
    }
}

struct BulletList: View {
    let title: String
    let items: [String]
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: symbol).labelStyle(.titleAndIcon)
            }
        }
    }
}
