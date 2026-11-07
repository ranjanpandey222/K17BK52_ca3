import SwiftUI
import SwiftData
import EbbCore

/// First-run flow. Collects the minimum needed, explains privacy, then hands
/// over to the paywall.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, aboutYou, lastPeriod, symptoms, treatment, reminder, health, privacy, ready
    }

    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.modelContext) private var modelContext

    @State private var step: Step = .welcome
    @State private var firstName = ""
    @State private var birthYear: Int = Calendar.current.component(.year, from: .now) - 48
    @State private var shareBirthYear = true
    @State private var lastPeriod: LastPeriodAnswer?
    @State private var selectedSymptoms = Set(SymptomCatalog.defaultTrackedIDs)
    @State private var treatmentKind: TreatmentKind?
    @State private var noTreatment = false
    @State private var treatmentName = ""
    @State private var treatmentStart = Date.now
    @State private var reminderOn = true
    @State private var reminderTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now
    @State private var acceptedDisclaimer = false

    private var steps: [Step] {
        Step.allCases.filter { $0 != .health || health.isAvailable }
    }

    private var progress: Double {
        guard let index = steps.firstIndex(of: step) else { return 0 }
        return Double(index) / Double(max(steps.count - 1, 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                HStack(spacing: 12) {
                    Button { goBack() } label: {
                        Image(systemName: "chevron.left").font(.headline).foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityLabel("Back")
                    ProgressView(value: progress).tint(Theme.accent)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)

            Button(primaryTitle) { advance() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            if let secondaryTitle {
                Button(secondaryTitle) { skip() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 12)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .aboutYou: aboutYou
        case .lastPeriod: lastPeriodStep
        case .symptoms: symptomsStep
        case .treatment: treatmentStep
        case .reminder: reminderStep
        case .health: healthStep
        case .privacy: privacyStep
        case .ready: readyStep
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 40)
            EbbLogo(size: 80)
            Text("Understand your menopause symptoms.")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Track how you feel in 30 seconds a day. Ebb finds your patterns and turns them into a report your doctor can act on.")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
            VStack(alignment: .leading, spacing: 14) {
                bullet("sparkles", "Find what triggers your hot flashes, poor sleep and mood swings")
                bullet("pills", "See whether your treatment is working")
                bullet("doc.text", "Walk into appointments with a clear report")
                bullet("lock.shield", "Private by design: your data stays on your phone")
            }
            .padding(.top, 8)
        }
    }

    private var aboutYou: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("A little about you", "This personalizes Ebb. It stays on your phone.")
            VStack(alignment: .leading, spacing: 8) {
                Text("First name (optional)").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textSecondary)
                TextField("Your first name", text: $firstName)
                    .textContentType(.givenName)
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            }
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Add my birth year", isOn: $shareBirthYear)
                    .font(.subheadline.weight(.medium))
                    .tint(Theme.accent)
                if shareBirthYear {
                    Picker("Birth year", selection: $birthYear) {
                        ForEach(birthYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                    Text("Helps Ebb explain which stage you may be in.")
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var lastPeriodStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("When was your last period?", "Optional. Menopause is defined as 12 months without a period, so this helps Ebb describe your stage. Ebb doesn't track periods.")
            ForEach(LastPeriodAnswer.allCases) { answer in
                optionRow(title: answer.title, subtitle: answer.subtitle, selected: lastPeriod == answer) {
                    lastPeriod = answer
                }
            }
        }
    }

    private var symptomsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("What would you like to track?", "We've picked the most common symptoms. You can change these any time.")
            ForEach(SymptomCategory.allCases, id: \.self) { category in
                let items = SymptomCatalog.all.filter { $0.category == category }
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(items) { symptom in
                            Chip(title: symptom.name, systemImage: symptom.systemImage, isSelected: selectedSymptoms.contains(symptom.id)) {
                                if selectedSymptoms.contains(symptom.id) {
                                    selectedSymptoms.remove(symptom.id)
                                } else {
                                    selectedSymptoms.insert(symptom.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var treatmentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Are you using any treatment?", "Optional. Ebb will compare how you feel before and after, so you can see if it's working.")
            optionRow(title: "Not right now", subtitle: nil, selected: noTreatment) {
                treatmentKind = nil
                noTreatment = true
            }
            ForEach([TreatmentKind.estrogenPatch, .estrogenGel, .estrogenPill, .combinedHRT, .progesterone, .nonHormonalMedicine, .supplement]) { kind in
                optionRow(title: kind.title, subtitle: nil, selected: treatmentKind == kind) {
                    treatmentKind = kind
                    noTreatment = false
                }
            }
            if let treatmentKind {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Name, e.g. \(treatmentKind.title)", text: $treatmentName)
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    DatePicker("Started on", selection: $treatmentStart, in: ...Date.now, displayedComponents: .date)
                        .tint(Theme.accent)
                    Text("You can add more treatments and doses later.")
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private var reminderStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("When should we remind you?", "A gentle daily nudge to check in. Most people choose the evening.")
            Toggle("Daily check-in reminder", isOn: $reminderOn).tint(Theme.accent).font(.headline)
            if reminderOn {
                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("Connect Apple Health?", "Optional. Ebb can show last night's sleep and Apple Watch temperature next to your symptoms, and save your symptoms to Health.")
            Card {
                Label("Read: sleep and wrist temperature", systemImage: "heart.text.square").foregroundStyle(Theme.textPrimary)
                Label("Write: the symptoms you log", systemImage: "square.and.arrow.down").foregroundStyle(Theme.textPrimary)
                Text("Health data never leaves your phone and is never used for advertising.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("Your privacy promise", "Menopause is personal. We built Ebb so it stays that way.")
            VStack(alignment: .leading, spacing: 14) {
                bullet("iphone", "Your check-ins are stored only on this iPhone")
                bullet("eye.slash", "No ad trackers, no social media SDKs, no selling data")
                bullet("cpu", "Patterns and summaries are calculated on your device")
                bullet("trash", "Export or delete everything at any time in Settings")
            }
            Card {
                Text(Disclaimer.short).font(.footnote).foregroundStyle(Theme.textSecondary)
                Toggle(isOn: $acceptedDisclaimer) {
                    Text("I understand").font(.subheadline.weight(.semibold))
                }
                .tint(Theme.accent)
            }
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            title(firstName.isEmpty ? "You're all set" : "You're all set, \(firstName)", "Here's your plan.")
            Card {
                planRow("checklist", "Track \(selectedSymptoms.count) symptoms in about 30 seconds a day")
                if reminderOn {
                    planRow("bell", "Reminder every day at \(reminderTime.formatted(date: .omitted, time: .shortened))")
                }
                planRow("sparkles", "Your first patterns after 7 check-ins")
                planRow("doc.text", "A doctor-ready report whenever you need it")
            }
            let stage = StageEstimator.estimate(lastPeriod: lastPeriod, age: shareBirthYear ? StageEstimator.age(birthYear: birthYear, today: .now) : nil)
            Card {
                Text(stage.title).font(.headline).foregroundStyle(Theme.textPrimary)
                Text(stage.explanation).font(.subheadline).foregroundStyle(Theme.textSecondary)
                Text(StageEstimate.disclaimer).font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - Navigation

    private var primaryTitle: String {
        switch step {
        case .welcome: return "Get started"
        case .health: return "Connect Apple Health"
        case .ready: return "Continue"
        default: return "Continue"
        }
    }

    private var secondaryTitle: String? {
        switch step {
        case .lastPeriod, .treatment: return "Skip"
        case .health: return "Not now"
        default: return nil
        }
    }

    private var canContinue: Bool {
        switch step {
        case .symptoms: return !selectedSymptoms.isEmpty
        case .lastPeriod: return lastPeriod != nil
        case .treatment:
            if treatmentKind != nil { return !treatmentName.trimmingCharacters(in: .whitespaces).isEmpty }
            return noTreatment
        case .privacy: return acceptedDisclaimer
        default: return true
        }
    }

    private func advance() {
        switch step {
        case .reminder:
            if reminderOn {
                Task { await NotificationService.requestPermission() }
            }
            moveForward()
        case .health:
            Task {
                let granted = await health.requestAuthorization(includeWrite: true)
                profile.healthReadEnabled = granted
                profile.healthWriteEnabled = granted
                moveForward()
            }
        case .ready:
            finish()
        default:
            moveForward()
        }
    }

    private func skip() {
        switch step {
        case .lastPeriod: lastPeriod = nil
        case .treatment:
            treatmentKind = nil
            noTreatment = true
        default: break
        }
        moveForward()
    }

    private func moveForward() {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        step = steps[index + 1]
    }

    private func goBack() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
    }

    private func finish() {
        profile.firstName = firstName.trimmingCharacters(in: .whitespaces)
        profile.birthYear = shareBirthYear ? birthYear : nil
        profile.lastPeriod = lastPeriod
        profile.trackedSymptomIDs = SymptomCatalog.normalized(Array(selectedSymptoms))
        profile.dailyReminderEnabled = reminderOn
        profile.reminderTime = reminderTime

        if let treatmentKind {
            let name = treatmentName.trimmingCharacters(in: .whitespaces)
            let treatment = Treatment(name: name.isEmpty ? treatmentKind.title : name, kind: treatmentKind, startDate: treatmentStart)
            if treatment.frequency.weekdayCount > 0 {
                let weekday = Calendar.current.component(.weekday, from: treatmentStart)
                treatment.reminderWeekdays = treatment.frequency == .twiceWeekly ? [weekday, ((weekday + 2) % 7) + 1] : [weekday]
            }
            modelContext.insert(treatment)
            try? modelContext.save()
        }

        if reminderOn {
            let hour = profile.dailyReminderHour
            let minute = profile.dailyReminderMinute
            Task { await NotificationService.scheduleDailyCheckIn(hour: hour, minute: minute) }
        }

        profile.onboardingComplete = true
    }

    // MARK: - Building blocks

    private var birthYears: [Int] {
        let current = Calendar.current.component(.year, from: .now)
        return Array((current - 80)...(current - 25)).reversed()
    }

    private func title(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title.weight(.bold)).foregroundStyle(Theme.textPrimary)
            Text(subtitle).font(.body).foregroundStyle(Theme.textSecondary)
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: icon, size: 34)
            Text(text).font(.body).foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        }
    }

    private func planRow(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text).foregroundStyle(Theme.textPrimary)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
    }

    private func optionRow(title: String, subtitle: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : Theme.cardBorder)
            }
            .padding(16)
            .background(selected ? Theme.accentSoft : Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
