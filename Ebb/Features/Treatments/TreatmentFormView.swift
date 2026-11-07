import SwiftUI
import SwiftData

/// Add, edit, or change the dose of a treatment.
struct TreatmentFormView: View {
    enum Mode {
        case add
        case edit(Treatment)
        /// Ends the existing treatment and starts a new record with the new dose.
        case changeDose(Treatment)
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TreatmentKind = .estrogenPatch
    @State private var name = ""
    @State private var dose = ""
    @State private var frequency: TreatmentFrequency = .twiceWeekly
    @State private var weekdays: Set<Int> = []
    @State private var startDate = Date.now
    @State private var reminderEnabled = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var notes = ""
    @State private var loaded = false

    private var title: String {
        switch mode {
        case .add: return "Add treatment"
        case .edit: return "Edit treatment"
        case .changeDose: return "Change dose"
        }
    }

    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if reminderEnabled, frequency.weekdayCount > 0 { return weekdays.count == frequency.weekdayCount }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                if let changingName = changeDoseName {
                    Section {
                        Text("\(changingName) will end and a new entry with the new dose will start, so Ebb can compare each dose separately.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Section("Treatment") {
                    Picker("Type", selection: $kind) {
                        ForEach(TreatmentKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    .disabled(isChangeDose)
                    TextField("Name (e.g. Estradiol patch)", text: $name)
                        .disabled(isChangeDose)
                    TextField("Dose (e.g. 50 mcg)", text: $dose)
                }

                Section("Schedule") {
                    Picker("How often", selection: $frequency) {
                        ForEach(TreatmentFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                    if frequency.weekdayCount > 0 {
                        weekdayPicker
                    }
                    DatePicker(isChangeDose ? "New dose from" : "Started on", selection: $startDate, displayedComponents: .date)
                }

                if frequency != .asNeeded {
                    Section {
                        Toggle("Remind me", isOn: $reminderEnabled)
                        if reminderEnabled {
                            DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        }
                    } footer: {
                        if reminderEnabled && frequency.weekdayCount > 0 && weekdays.count != frequency.weekdayCount {
                            Text("Choose \(frequency.weekdayCount == 1 ? "1 day" : "\(frequency.weekdayCount) days") above.")
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .tint(Theme.accent)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isValid)
                }
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, newKind in
                if case .add = mode {
                    frequency = newKind.defaultFrequency
                    if name.isEmpty || TreatmentKind.allCases.map(\.title).contains(name) {
                        name = newKind.title
                    }
                }
            }
            .onChange(of: frequency) { _, newFrequency in
                if weekdays.count > newFrequency.weekdayCount {
                    weekdays = Set(weekdays.sorted().prefix(newFrequency.weekdayCount))
                }
            }
        }
    }

    private var isChangeDose: Bool {
        if case .changeDose = mode { return true }
        return false
    }

    private var changeDoseName: String? {
        if case .changeDose(let existing) = mode { return existing.name }
        return nil
    }

    private var weekdayPicker: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let selected = weekdays.contains(weekday)
                Button {
                    if selected {
                        weekdays.remove(weekday)
                    } else if weekdays.count < frequency.weekdayCount {
                        weekdays.insert(weekday)
                    } else if frequency.weekdayCount == 1 {
                        weekdays = [weekday]
                    }
                } label: {
                    Text(symbols[weekday - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(selected ? .white : Theme.textPrimary)
                        .background(selected ? Theme.accent : Theme.card, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .add:
            name = kind.title
            frequency = kind.defaultFrequency
        case .edit(let existing), .changeDose(let existing):
            kind = existing.kind
            name = existing.name
            dose = existing.dose
            frequency = existing.frequency
            weekdays = Set(existing.reminderWeekdays)
            startDate = isChangeDose ? .now : existing.startDate
            reminderEnabled = existing.reminderEnabled
            reminderTime = Calendar.current.date(bySettingHour: existing.reminderHour, minute: existing.reminderMinute, second: 0, of: .now) ?? .now
            notes = existing.notes
        }
    }

    private func save() {
        let target: Treatment
        switch mode {
        case .add:
            target = Treatment(name: "", kind: kind)
            modelContext.insert(target)
        case .edit(let existing):
            target = existing
        case .changeDose(let existing):
            existing.endDate = Calendar.current.startOfDay(for: startDate)
            existing.reminderEnabled = false
            let oldID = existing.id
            Task { await NotificationService.cancelTreatmentReminders(id: oldID) }
            target = Treatment(name: existing.name, kind: existing.kind)
            target.previousTreatmentID = existing.id
            modelContext.insert(target)
        }

        target.kind = kind
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.dose = dose.trimmingCharacters(in: .whitespaces)
        target.frequency = frequency
        target.reminderWeekdays = weekdays.sorted()
        target.startDate = Calendar.current.startOfDay(for: startDate)
        target.reminderEnabled = reminderEnabled && frequency != .asNeeded
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        target.reminderHour = parts.hour ?? 9
        target.reminderMinute = parts.minute ?? 0
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()

        let id = target.id
        let reminderName = target.displayName
        let enabled = target.reminderEnabled
        let scheduleFrequency = target.frequency
        let scheduleWeekdays = target.reminderWeekdays
        let hour = target.reminderHour
        let minute = target.reminderMinute
        Task {
            if enabled {
                await NotificationService.requestPermission()
                await NotificationService.scheduleTreatmentReminders(
                    id: id, name: reminderName, frequency: scheduleFrequency, weekdays: scheduleWeekdays, hour: hour, minute: minute
                )
            } else {
                await NotificationService.cancelTreatmentReminders(id: id)
            }
        }
        dismiss()
    }
}
