import SwiftUI
import SwiftData
import EbbCore

struct MoreView: View {
    @State private var showReport = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showReport = true
                    } label: {
                        Label("Doctor report", systemImage: "doc.text")
                    }
                    NavigationLink {
                        LearnListView()
                    } label: {
                        Label("Learn", systemImage: "book")
                    }
                }
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                Section {
                    Text(Disclaimer.short).font(.footnote).foregroundStyle(Theme.textSecondary)
                    Text(Disclaimer.emergency).font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .foregroundStyle(Theme.textPrimary)
            .navigationTitle("More")
            .sheet(isPresented: $showReport) { ReportView() }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var appLock: AppLockService
    @Environment(\.modelContext) private var modelContext

    @Query private var logs: [DayLog]
    @Query private var treatments: [Treatment]

    @State private var showManageSubscription = false
    @State private var showDeleteConfirm = false
    @State private var exportURL: URL?
    @State private var exportError = false

    var body: some View {
        List {
            profileSection
            trackingSection
            remindersSection
            healthSection
            privacySection
            subscriptionSection
            dataSection
            aboutSection
        }
        .tint(Theme.accent)
        .navigationTitle("Settings")
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .confirmationDialog("Delete all your data?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { deleteAll() }
        } message: {
            Text("This permanently deletes all check-ins, treatments and settings from this iPhone. It can't be undone. Your subscription isn't affected.")
        }
        .alert("Export failed", isPresented: $exportError) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section("Profile") {
            TextField("First name", text: $profile.firstName)
            Picker("Birth year", selection: Binding(
                get: { profile.birthYear ?? 0 },
                set: { profile.birthYear = $0 == 0 ? nil : $0 }
            )) {
                Text("Not set").tag(0)
                ForEach(birthYears, id: \.self) { Text(String($0)).tag($0) }
            }
            Picker("Last period", selection: Binding(
                get: { profile.lastPeriodRaw ?? "" },
                set: { profile.lastPeriodRaw = $0.isEmpty ? nil : $0 }
            )) {
                Text("Not set").tag("")
                ForEach(LastPeriodAnswer.allCases) { Text($0.title).tag($0.rawValue) }
            }
        }
    }

    private var trackingSection: some View {
        Section {
            NavigationLink("Symptoms I track (\(profile.trackedSymptomIDs.count))") {
                TrackedSymptomsView()
            }
            Toggle("Count hot flashes", isOn: $profile.countHotFlashes)
        } header: {
            Text("Tracking")
        } footer: {
            Text("Counting is optional. It adds a counter to the check-in when you log hot flashes.")
        }
    }

    private var remindersSection: some View {
        Section("Daily reminder") {
            Toggle("Check-in reminder", isOn: Binding(
                get: { profile.dailyReminderEnabled },
                set: { newValue in
                    profile.dailyReminderEnabled = newValue
                    updateDailyReminder()
                }
            ))
            if profile.dailyReminderEnabled {
                DatePicker("Time", selection: Binding(
                    get: { profile.reminderTime },
                    set: { newValue in
                        profile.reminderTime = newValue
                        updateDailyReminder()
                    }
                ), displayedComponents: .hourAndMinute)
            }
        }
    }

    @ViewBuilder
    private var healthSection: some View {
        if health.isAvailable {
            Section {
                Toggle("Show sleep & temperature", isOn: Binding(
                    get: { profile.healthReadEnabled },
                    set: { newValue in
                        if newValue {
                            Task {
                                profile.healthReadEnabled = await health.requestAuthorization(includeWrite: profile.healthWriteEnabled)
                                await health.refresh()
                            }
                        } else {
                            profile.healthReadEnabled = false
                        }
                    }
                ))
                Toggle("Save symptoms to Health", isOn: Binding(
                    get: { profile.healthWriteEnabled },
                    set: { newValue in
                        if newValue {
                            Task { profile.healthWriteEnabled = await health.requestAuthorization(includeWrite: true) }
                        } else {
                            profile.healthWriteEnabled = false
                        }
                    }
                ))
            } header: {
                Text("Apple Health")
            } footer: {
                Text("To change what Ebb can access, open the Health app → your profile → Apps → Ebb.")
            }
        }
    }

    private var privacySection: some View {
        Section {
            if appLock.canUseLock {
                Toggle("Lock with \(appLock.biometryName)", isOn: Binding(
                    get: { profile.appLockEnabled },
                    set: { newValue in
                        if newValue {
                            Task {
                                if await appLock.verify() { profile.appLockEnabled = true }
                            }
                        } else {
                            profile.appLockEnabled = false
                            appLock.disable()
                        }
                    }
                ))
            }
            Link("Privacy policy", destination: AppConfig.privacyPolicyURL)
        } header: {
            Text("Privacy")
        } footer: {
            Text("Your check-ins are stored only on this iPhone. Ebb has no ad trackers and never sells data.")
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            HStack {
                Text("Status")
                Spacer()
                Text(store.isPremium ? "Ebb Premium" : "Not subscribed").foregroundStyle(Theme.textSecondary)
            }
            Button("Manage subscription") { showManageSubscription = true }
            Button("Restore purchases") { Task { await store.restorePurchases() } }
            #if DEBUG
            Toggle("Debug: unlock without buying", isOn: $store.debugUnlocked)
            Button("Debug: load 10 weeks of sample data") { DemoData.seed(into: modelContext) }
            #endif
        }
    }

    private var dataSection: some View {
        Section {
            if let exportURL {
                ShareLink(item: exportURL) { Label("Share export file", systemImage: "square.and.arrow.up") }
            } else {
                Button {
                    do {
                        exportURL = try DataRepository.exportJSON(logs: logs, treatments: treatments)
                    } catch {
                        exportError = true
                    }
                } label: {
                    Label("Export my data", systemImage: "arrow.down.doc")
                }
            }
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete all my data", systemImage: "trash")
            }
        } header: {
            Text("Your data")
        } footer: {
            Text("Export creates a file with all your check-ins and treatments that you can save or send.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Link("Terms of use", destination: AppConfig.termsURL)
            Link("Contact support", destination: URL(string: "mailto:\(AppConfig.supportEmail)")!)
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion).foregroundStyle(Theme.textSecondary)
            }
            Text(Disclaimer.short).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Actions

    private var birthYears: [Int] {
        let current = Calendar.current.component(.year, from: .now)
        return Array((current - 80)...(current - 25)).reversed()
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func updateDailyReminder() {
        let enabled = profile.dailyReminderEnabled
        let hour = profile.dailyReminderHour
        let minute = profile.dailyReminderMinute
        Task {
            if enabled {
                await NotificationService.requestPermission()
                await NotificationService.scheduleDailyCheckIn(hour: hour, minute: minute)
            } else {
                NotificationService.cancelDailyCheckIn()
            }
        }
    }

    private func deleteAll() {
        DataRepository.deleteAll(in: modelContext)
        NotificationService.cancelAll()
        appLock.disable()
        exportURL = nil
        profile.reset()
    }
}

struct TrackedSymptomsView: View {
    @EnvironmentObject private var profile: ProfileStore

    var body: some View {
        List {
            ForEach(SymptomCategory.allCases, id: \.self) { category in
                Section(category.title) {
                    ForEach(SymptomCatalog.all.filter { $0.category == category }) { symptom in
                        Toggle(isOn: Binding(
                            get: { profile.trackedSymptomIDs.contains(symptom.id) },
                            set: { isOn in
                                var ids = profile.trackedSymptomIDs
                                if isOn {
                                    ids.append(symptom.id)
                                } else if ids.count > 1 {
                                    ids.removeAll { $0 == symptom.id }
                                }
                                profile.trackedSymptomIDs = SymptomCatalog.normalized(ids)
                            }
                        )) {
                            Label(symptom.name, systemImage: symptom.systemImage)
                        }
                    }
                }
            }
        }
        .tint(Theme.accent)
        .navigationTitle("Symptoms I track")
    }
}
