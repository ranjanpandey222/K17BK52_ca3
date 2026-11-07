import SwiftUI
import SwiftData
import EbbCore

struct TreatmentsView: View {
    @Query(sort: \Treatment.startDate, order: .reverse) private var treatments: [Treatment]
    @State private var showAdd = false

    private var active: [Treatment] { treatments.filter(\.isActive) }
    private var past: [Treatment] { treatments.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    if treatments.isEmpty {
                        Card {
                            EmptyStateView(
                                systemImage: "pills",
                                title: "Track your treatments",
                                message: "Add HRT, non-hormonal medicines or supplements. Ebb compares how you feel before and after, so you can see what's working."
                            )
                            Button("Add a treatment") { showAdd = true }.buttonStyle(PrimaryButtonStyle())
                        }
                    } else {
                        if !active.isEmpty {
                            SectionHeader(title: "Current")
                            ForEach(active) { treatment in row(treatment) }
                        }
                        if !past.isEmpty {
                            SectionHeader(title: "Past").padding(.top, 8)
                            ForEach(past) { treatment in row(treatment) }
                        }
                    }
                    Text(Disclaimer.short).font(.caption).foregroundStyle(Theme.textSecondary).padding(.top, 8)
                }
                .padding(20)
            }
            .ebbScreen()
            .navigationTitle("Treatments")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add treatment")
                }
            }
            .navigationDestination(for: Treatment.self) { treatment in
                TreatmentDetailView(treatment: treatment)
            }
            .sheet(isPresented: $showAdd) {
                TreatmentFormView(mode: .add)
            }
        }
    }

    private func row(_ treatment: Treatment) -> some View {
        NavigationLink(value: treatment) {
            Card {
                HStack(spacing: 12) {
                    IconBadge(systemImage: treatment.kind.systemImage)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(treatment.displayName).font(.headline).foregroundStyle(Theme.textPrimary)
                        Text(subtitle(treatment)).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func subtitle(_ treatment: Treatment) -> String {
        let since = treatment.startDate.formatted(date: .abbreviated, time: .omitted)
        if let end = treatment.endDate, !treatment.isActive {
            return "\(since) – \(end.formatted(date: .abbreviated, time: .omitted))"
        }
        return "\(treatment.frequency.title) · since \(since)"
    }
}

// MARK: - Detail

struct TreatmentDetailView: View {
    @Bindable var treatment: Treatment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query private var allTreatments: [Treatment]

    @State private var showEdit = false
    @State private var showChangeDose = false
    @State private var showStopConfirm = false
    @State private var showDeleteConfirm = false

    private var comparison: TreatmentComparison {
        PatternEngine().treatmentComparison(for: treatment.period, records: logs.map(\.record), today: .now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                Card {
                    HStack(spacing: 12) {
                        IconBadge(systemImage: treatment.kind.systemImage, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(treatment.name).font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            Text(treatment.kind.title).font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    detailRow("Dose", treatment.dose.isEmpty ? "Not set" : treatment.dose)
                    detailRow("How often", treatment.frequency.title)
                    detailRow("Started", treatment.startDate.formatted(date: .long, time: .omitted))
                    if let end = treatment.endDate {
                        detailRow("Stopped", end.formatted(date: .long, time: .omitted))
                    }
                    if treatment.reminderEnabled {
                        detailRow("Reminder", reminderText)
                    }
                    if !treatment.notes.isEmpty {
                        Text(treatment.notes).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                }

                comparisonCard

                if treatment.isActive {
                    Button("Change dose") { showChangeDose = true }.buttonStyle(SecondaryButtonStyle())
                    Button("Stop this treatment") { showStopConfirm = true }.buttonStyle(SecondaryButtonStyle())
                }
                Button("Delete", role: .destructive) { showDeleteConfirm = true }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .ebbScreen()
        .navigationTitle(treatment.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Edit") { showEdit = true } }
        }
        .sheet(isPresented: $showEdit) { TreatmentFormView(mode: .edit(treatment)) }
        .sheet(isPresented: $showChangeDose) { TreatmentFormView(mode: .changeDose(treatment)) }
        .confirmationDialog("Stop \(treatment.name) today?", isPresented: $showStopConfirm, titleVisibility: .visible) {
            Button("Stop treatment") { stop() }
        } message: {
            Text("It moves to Past, and its reminders are turned off. Your history is kept.")
        }
        .confirmationDialog("Delete \(treatment.name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("This removes the treatment and its dose history. Your check-ins are kept.")
        }
    }

    private var comparisonCard: some View {
        Card {
            SectionHeader(title: "Is it working?", subtitle: "Your symptoms in the 4 weeks before vs. weeks 3–6 after starting")
            switch comparison.status {
            case .ready:
                Text(comparison.summary).font(.headline).foregroundStyle(Theme.textPrimary)
                ForEach(comparison.symptomChanges.prefix(6), id: \.symptomID) { change in
                    changeRow(change)
                }
                if let before = comparison.hotFlashesPerDayBefore, let after = comparison.hotFlashesPerDayAfter {
                    Text("Hot flashes per counted day: \(Phrasing.oneDecimal(before)) → \(Phrasing.oneDecimal(after))")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                let overlapping = PatternEngine().overlappingTreatments(for: treatment.period, in: allTreatments.map(\.period))
                if !overlapping.isEmpty {
                    Label("You also started or stopped \(overlapping.map(\.name).joined(separator: " and ")) around this time, so the change can't be put down to this treatment alone.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(Theme.warning)
                }
                Text("Other things can change at the same time, so use this as a conversation starter with your clinician.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            default:
                Text(comparison.summary).foregroundStyle(Theme.textPrimary)
                Text("Ebb compares the 28 days before you started with days 15–42 after, giving the treatment time to take effect.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func changeRow(_ change: SymptomChange) -> some View {
        HStack {
            Text(SymptomCatalog.name(for: change.symptomID)).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(Phrasing.oneDecimal(change.before)) → \(Phrasing.oneDecimal(change.after))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            Image(systemName: change.difference < -0.25 ? "arrow.down.right" : (change.difference > 0.25 ? "arrow.up.right" : "arrow.right"))
                .foregroundStyle(change.difference < -0.25 ? Theme.positive : (change.difference > 0.25 ? Theme.warning : Theme.textSecondary))
        }
        .font(.subheadline)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var reminderText: String {
        let time = Calendar.current.date(bySettingHour: treatment.reminderHour, minute: treatment.reminderMinute, second: 0, of: .now) ?? .now
        let timeText = time.formatted(date: .omitted, time: .shortened)
        guard treatment.frequency.weekdayCount > 0 else { return timeText }
        let symbols = Calendar.current.shortWeekdaySymbols
        let days = treatment.reminderWeekdays.sorted().compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
        return "\(days.joined(separator: ", ")) at \(timeText)"
    }

    private func stop() {
        treatment.endDate = Calendar.current.startOfDay(for: .now)
        treatment.reminderEnabled = false
        try? modelContext.save()
        let id = treatment.id
        Task { await NotificationService.cancelTreatmentReminders(id: id) }
    }

    private func delete() {
        let id = treatment.id
        let doses = (try? modelContext.fetch(FetchDescriptor<DoseLog>(predicate: #Predicate { $0.treatmentID == id }))) ?? []
        for dose in doses { modelContext.delete(dose) }
        modelContext.delete(treatment)
        try? modelContext.save()
        Task { await NotificationService.cancelTreatmentReminders(id: id) }
        dismiss()
    }
}
