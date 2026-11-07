import SwiftUI
import UIKit
import SwiftData
import EbbCore

/// The daily check-in (also used to edit past days).
struct CheckInView: View {
    let day: Date

    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: Int] = [:]
    @State private var triggers: Set<String> = []
    @State private var hotFlashCount = 0
    @State private var note = ""
    @State private var isExisting = false
    @State private var showDeleteConfirm = false
    @State private var loaded = false

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    /// Tracked symptoms plus anything already logged that day.
    private var symptomIDs: [String] {
        SymptomCatalog.normalized(profile.trackedSymptomIDs + Array(values.keys))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(isToday ? "How has today been?" : day.formatted(date: .complete, time: .omitted))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)

                    ForEach(SymptomCategory.allCases, id: \.self) { category in
                        let ids = symptomIDs.filter { SymptomCatalog.definition(for: $0)?.category == category }
                        if !ids.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                                ForEach(ids, id: \.self) { id in
                                    symptomRow(id)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Anything that might matter?", subtitle: "Tap what applied today. Ebb looks for links with your symptoms.")
                        FlowLayout(spacing: 8) {
                            ForEach(TriggerCatalog.all) { trigger in
                                Chip(title: trigger.name, systemImage: trigger.systemImage, isSelected: triggers.contains(trigger.id)) {
                                    if triggers.contains(trigger.id) { triggers.remove(trigger.id) } else { triggers.insert(trigger.id) }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        TextField("Anything else worth remembering?", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    }

                    if isExisting {
                        Button("Delete this check-in", role: .destructive) { showDeleteConfirm = true }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(isExisting ? "Save changes" : "Save check-in") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
            }
            .navigationTitle(isToday ? "Check-in" : "Edit check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog("Delete this check-in?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteLog() }
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private func symptomRow(_ id: String) -> some View {
        let definition = SymptomCatalog.definition(for: id)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconBadge(systemImage: definition?.systemImage ?? "circle", size: 30)
                Text(SymptomCatalog.name(for: id)).font(.body.weight(.medium)).foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            SeveritySelector(value: Binding(
                get: { values[id] ?? 0 },
                set: { values[id] = $0 }
            ))
            if id == SymptomCatalog.hotFlashes && profile.countHotFlashes && (values[id] ?? 0) > 0 {
                Stepper(value: $hotFlashCount, in: 0...50) {
                    Text(hotFlashCount == 0 ? "How many? (optional)" : "\(hotFlashCount) hot flash\(hotFlashCount == 1 ? "" : "es")")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing = DataRepository.dayLog(for: day, in: modelContext) {
            isExisting = true
            values = existing.symptoms
            triggers = Set(existing.triggerIDs)
            note = existing.note
            hotFlashCount = existing.hotFlashCount ?? 0
        }
        for id in profile.trackedSymptomIDs where values[id] == nil {
            values[id] = 0
        }
    }

    private func save() {
        let log = DataRepository.dayLogCreatingIfNeeded(for: day, in: modelContext)
        var symptoms: [String: Int] = [:]
        for id in symptomIDs { symptoms[id] = Severity.clamped(values[id] ?? 0) }
        log.symptoms = symptoms
        log.triggerIDs = TriggerCatalog.all.map(\.id).filter { triggers.contains($0) }
        // A count is only stored when the user entered one on a day with hot flashes.
        let hasHotFlashes = (symptoms[SymptomCatalog.hotFlashes] ?? 0) > 0
        log.hotFlashCount = hasHotFlashes && hotFlashCount > 0 ? hotFlashCount : nil
        log.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        log.updatedAt = .now
        try? modelContext.save()

        if profile.healthWriteEnabled {
            let day = self.day
            Task { await health.saveSymptoms(symptoms, day: day) }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }

    private func deleteLog() {
        if let existing = DataRepository.dayLog(for: day, in: modelContext) {
            modelContext.delete(existing)
            try? modelContext.save()
        }
        if profile.healthWriteEnabled {
            let day = self.day
            Task { await health.saveSymptoms([:], day: day) }
        }
        dismiss()
    }
}
