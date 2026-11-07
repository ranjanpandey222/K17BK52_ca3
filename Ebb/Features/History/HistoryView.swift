import SwiftUI
import SwiftData
import EbbCore

/// Month calendar colored by symptom score (or by one symptom's severity).
struct HistoryView: View {
    @EnvironmentObject private var profile: ProfileStore
    @Query(sort: \DayLog.day) private var logs: [DayLog]

    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var filter: String = "overall"
    @State private var editingDay: EditableDay?

    private let calendar = Calendar.current

    private var logsByKey: [String: DayLog] {
        Dictionary(logs.map { ($0.dayKey, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var filterOptions: [String] {
        let logged = Set(logs.flatMap { $0.symptoms.keys })
        return ["overall"] + SymptomCatalog.normalized(profile.trackedSymptomIDs + Array(logged))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    filterPicker
                    Card {
                        monthHeader
                        weekdayHeader
                        monthGrid
                        legend
                    }
                    monthSummary
                }
                .padding(20)
            }
            .ebbScreen()
            .navigationTitle("History")
            .sheet(item: $editingDay) { item in
                CheckInView(day: item.date)
            }
        }
    }

    // MARK: - Pieces

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterOptions, id: \.self) { option in
                    Chip(
                        title: option == "overall" ? "Overall" : SymptomCatalog.name(for: option),
                        isSelected: filter == option
                    ) { filter = option }
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
                .disabled(isCurrentMonth)
                .accessibilityLabel("Next month")
        }
        .font(.headline)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return HStack {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let key = DayKey.string(from: day)
        let log = logsByKey[key]
        let isFuture = day > Date.now
        let isToday = calendar.isDateInToday(day)

        return Button {
            editingDay = EditableDay(date: day)
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .foregroundStyle(cellTextColor(log: log))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(cellColor(log: log), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isToday ? Theme.accent : Color.clear, lineWidth: 2)
                )
                .opacity(isFuture ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityText(day: day, log: log))
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: Theme.scoreColor(nil), text: "No check-in")
            legendItem(color: Theme.scoreColor(0), text: "None")
            legendItem(color: Theme.severityColor(1), text: "Mild")
            legendItem(color: Theme.severityColor(3), text: "Severe")
        }
        .font(.caption2)
        .foregroundStyle(Theme.textSecondary)
        .padding(.top, 4)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text)
        }
    }

    private var monthSummary: some View {
        let monthLogs = logs.filter { calendar.isDate($0.day, equalTo: month, toGranularity: .month) }
        let scores = monthLogs.compactMap { $0.record.score }
        let average = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
        return Card {
            SectionHeader(title: "This month")
            HStack {
                summaryStat(value: "\(monthLogs.count)", label: "check-ins")
                summaryStat(value: average.map { String(Int($0.rounded())) } ?? "–", label: "avg score (0–100)")
            }
            Text("Tap any day to add or edit a check-in.").font(.footnote).foregroundStyle(Theme.textSecondary)
        }
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.weight(.bold)).foregroundStyle(Theme.textPrimary)
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private func changeMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) {
            month = next
        }
    }

    /// Days of the month, padded with nils so the first day lands on the right weekday.
    private var gridDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: month))
        }
        return days
    }

    private func value(for log: DayLog?) -> Double? {
        guard let log else { return nil }
        if filter == "overall" { return log.record.score }
        guard let severity = log.symptoms[filter] else { return nil }
        return Double(severity) / 3 * 100
    }

    private func cellColor(log: DayLog?) -> Color {
        Theme.scoreColor(value(for: log))
    }

    private func cellTextColor(log: DayLog?) -> Color {
        guard let value = value(for: log), value > 50 else { return Theme.textPrimary }
        return .white
    }

    private func accessibilityText(day: Date, log: DayLog?) -> String {
        let date = day.formatted(date: .long, time: .omitted)
        guard let value = value(for: log) else { return "\(date), no check-in" }
        return "\(date), score \(Int(value.rounded()))"
    }
}

struct EditableDay: Identifiable {
    let date: Date
    var id: Date { date }
}
