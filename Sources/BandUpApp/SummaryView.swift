import BandUpCore
import Charts
import SwiftUI

/// The main window: a summary of everything practised so far.
struct SummaryView: View {
    @Environment(AppModel.self) private var model

    private var progress: LearnerProgress { model.progress }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                stats
                HStack(alignment: .top, spacing: 20) {
                    card("Last 14 days") { ActivityChart(days: progress.activity(days: 14)) }
                    card("Words by level") { LevelChart(counts: progress.levelCounts(in: model.bank)) }
                }
                card("Writing & speaking bands") { BandChart(points: progress.bandHistory()) }
                card("Words to work on") { strugglingList }
            }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.top)
        .navigationTitle("Progress")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting).font(.largeTitle.bold())
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Quiz me", systemImage: "bolt.fill") { model.startQuiz() }
                    .buttonStyle(.borderedProminent)
                Button("Speak", systemImage: "mic.fill") { model.open("speaking") }
                Button("Write", systemImage: "pencil") { model.open("writing") }
            }
            .controlSize(.large)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    private var subtitle: String {
        let due = progress.dueCount()
        if progress.reviews.isEmpty { return "Answer your first pop-up to start tracking progress." }
        if due > 0 { return "\(due) word\(due == 1 ? "" : "s") ready for review." }
        if let next = model.nextPing { return "All caught up. Next pop-up around \(next.formatted(date: .omitted, time: .shortened))." }
        return "All caught up."
    }

    private var stats: some View {
        let lastWriting = progress.bandHistory().last { $0.kind == .writing }
        let lastSpeaking = progress.bandHistory().last { $0.kind == .speaking }
        return HStack(spacing: 12) {
            StatTile(value: "\(progress.currentStreak())", label: "day streak", icon: "flame.fill")
            StatTile(value: "\(progress.learnedCount)", label: "words learned", icon: "checkmark.seal.fill",
                     detail: "\(progress.reviews.count) seen")
            StatTile(value: progress.accuracy().map { "\(Int(($0 * 100).rounded()))%" } ?? "–",
                     label: "right, last 7 days", icon: "target")
            StatTile(value: lastWriting.map { band($0.band) } ?? "–", label: "last writing", icon: "pencil")
            StatTile(value: lastSpeaking.map { band($0.band) } ?? "–", label: "last speaking", icon: "mic.fill")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var strugglingList: some View {
        let words = progress.struggling(in: model.bank)
        if words.isEmpty {
            Text("Nothing yet. Words you miss will show up here so you can drill them.")
                .foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(words, id: \.word.id) { item in
                    Button { model.startQuiz(with: item.word) } label: {
                        HStack {
                            Text(item.word.word).font(.body.weight(.semibold))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            LevelBadge(level: item.word.level)
                            Spacer()
                            Text("missed \(item.wrong)×").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Practise this word now")
                }
            }
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func band(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1))) }
}

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(value).font(.system(size: 28, weight: .bold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
            if let detail { Text(detail).font(.caption2).foregroundStyle(.tertiary) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Word answers per day; a single series, so no legend.
private struct ActivityChart: View {
    let days: [DayCount]

    var body: some View {
        Chart(days, id: \.day) { day in
            BarMark(x: .value("Day", day.day, unit: .day), y: .value("Words answered", day.words), width: .ratio(0.6))
                .foregroundStyle(ChartColors.writing)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) {
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { AxisGridLine().foregroundStyle(.quaternary); AxisValueLabel() }
        }
        .chartYScale(domain: 0...Double(max(days.map(\.words).max() ?? 0, 4)) * 1.15)
        .chartYAxisLabel("words answered")
        .frame(height: 180)
        .overlay {
            if days.allSatisfy({ $0.words == 0 }) {
                Text("No answers yet").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

/// Words per CEFR level, stacked: learned (solid) under seen-but-not-yet-learned (pale).
private struct LevelChart: View {
    let counts: [LevelCount]

    private var top: Int { max(counts.map(\.seen).max() ?? 0, 4) }

    var body: some View {
        Chart {
            ForEach(counts, id: \.level) { c in
                BarMark(x: .value("Level", c.level.rawValue), y: .value("Words", c.learned), width: .ratio(0.6))
                    .foregroundStyle(c.level.color)
                BarMark(x: .value("Level", c.level.rawValue), y: .value("Words", c.seen - c.learned), width: .ratio(0.6))
                    .foregroundStyle(c.level.color.opacity(0.35))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                    .annotation(position: .top) {
                        if c.seen > 0 {
                            Text("\(c.learned)/\(c.seen)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .chartYScale(domain: 0...Double(top) * 1.2)
        .chartYAxis {
            AxisMarks { AxisGridLine().foregroundStyle(.quaternary); AxisValueLabel() }
        }
        .frame(height: 180)
        Text("Solid = learned (remembered across about a week), pale = seen. Label shows learned/seen.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

/// Estimated bands over time. Two series on one 0–9 axis, with a legend.
private struct BandChart: View {
    let points: [BandPoint]
    @State private var selected: Date?

    private var nearest: BandPoint? {
        guard let selected else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }

    var body: some View {
        if points.isEmpty {
            Text("Finish a writing or speaking practice to see your estimated band here.")
                .foregroundStyle(.secondary)
        } else {
            Chart {
                ForEach(points, id: \.self) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Band", p.band),
                             series: .value("Skill", name(p.kind)))
                        .foregroundStyle(by: .value("Skill", name(p.kind)))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Date", p.date), y: .value("Band", p.band))
                        .foregroundStyle(by: .value("Skill", name(p.kind)))
                        .symbolSize(60)
                }
                RuleMark(y: .value("Goal", 7))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("band 7").font(.caption2).foregroundStyle(.secondary)
                    }
                if let p = nearest {
                    RuleMark(x: .value("Date", p.date))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2)
                                Text("\(name(p.kind)) · \(p.band.formatted(.number.precision(.fractionLength(1))))")
                                    .font(.caption.bold())
                            }
                            .padding(6)
                            .background(.background, in: RoundedRectangle(cornerRadius: 6))
                            .shadow(radius: 2)
                        }
                }
            }
            .chartForegroundStyleScale(["Writing": ChartColors.writing, "Speaking": ChartColors.speaking])
            .chartYScale(domain: 0...9)
            .chartYAxis {
                AxisMarks(values: [0, 3, 5, 7, 9]) { AxisGridLine().foregroundStyle(.quaternary); AxisValueLabel() }
            }
            .chartLegend(position: .top, alignment: .leading)
            .chartXSelection(value: $selected)
            .frame(height: 220)
            Text("Rough on-device estimates, not official scores.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func name(_ kind: PracticeEntry.Kind) -> String { kind == .writing ? "Writing" : "Speaking" }
}
