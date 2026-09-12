//
//  SettingsView.swift
//  Solace
//

import CloudKit
import SwiftUI

/// Profile, targets, scoring weights, allergen/diet safety, Apple ecosystem
/// toggles, and both AI tiers (on-device always available; cloud BYOK
/// opt-in per Section 7).
struct SettingsView: View {
    var cloudAIOnly = false
    var onClose: (() -> Void)?

    private enum Field: Hashable { case target, birthYear, height, weight, allergen, endpoint, model, apiKey }
    @FocusState private var focusedField: Field?
    @State private var profile = UserProfile(id: UUID())
    @State private var newAllergen = ""
    @State private var aiSettings = AIProviderSettings(id: UUID())
    @State private var apiKey = ""
    @State private var isLoaded = false
    @State private var saveError: String?
    @State private var showOnboarding = false
    @State private var iCloudAccountStatus: CKAccountStatus?

    @State private var profileSaveTask: Task<Void, Never>?
    @State private var aiSettingsSaveTask: Task<Void, Never>?
    @State private var apiKeySaveTask: Task<Void, Never>?

    private var profileValidation: String? {
        if let target = profile.dailyCalorieTargetOverride, !(1...10000).contains(target) {
            return "Enter a calorie target from 1 to 10,000, or clear it."
        }
        let year = Calendar.current.component(.year, from: Date())
        if let birthYear = profile.birthYear, !(year - 120...year).contains(birthYear) {
            return "Enter a valid birth year."
        }
        if let height = profile.heightCm, !height.isFinite || height <= 0 || height > 300 {
            return "Enter a height greater than 0 and up to 300 cm."
        }
        if let weight = profile.weightKg, !weight.isFinite || weight <= 0 || weight > 1000 {
            return "Enter a weight greater than 0 and up to 1,000 kg."
        }
        return nil
    }

    private static let dietaryFlagOptions: [(id: String, label: String)] = [
        ("vegan", "Vegan"), ("vegetarian", "Vegetarian"), ("glutenfree", "Gluten-Free"),
        ("halal", "Halal"), ("kosher", "Kosher"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color.solaceDestructive)
                        Button("Retry saving") {
                            Task {
                                do {
                                    guard profileValidation == nil else { return }
                                    try await UserProfileRepository.update(profile)
                                    try await AIProviderSettingsRepository.update(aiSettings)
                                    self.saveError = nil
                                } catch { self.saveError = error.localizedDescription }
                            }
                        }
                    }
                }
                if !cloudAIOnly {
                    metabolicTargetSection
                    allergenSection
                    dietarySection
                    appleEcosystemSection
                    aiSection
                    scoringWeightsSection
                }
                cloudAISection
                if !cloudAIOnly {
                    #if DEBUG
                        DevSettingsSection(onDataChanged: reload)
                    #endif
                    aboutSection
                }
            }
            .navigationTitle(cloudAIOnly ? "Photo AI" : "Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
                if let onClose {
                    if saveError != nil {
                        ToolbarItem(placement: .cancellationAction) { Button("Close", action: onClose) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            Task {
                                await profileSaveTask?.value
                                await aiSettingsSaveTask?.value
                                await apiKeySaveTask?.value
                                if saveError == nil { onClose() }
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showOnboarding, onDismiss: { Task { await reload() } }) {
                OnboardingView { showOnboarding = false }
            }
            .task { await reload() }
            .task { iCloudAccountStatus = try? await CKContainer.default().accountStatus() }
            .onChange(of: profile) { _, newValue in
                guard isLoaded else { return }
                profileSaveTask?.cancel()
                guard profileValidation == nil else { return }
                profileSaveTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    do {
                        try await UserProfileRepository.update(newValue)
                        saveError = nil
                    } catch { saveError = "Your profile changes couldn’t be saved. Please retry." }
                }
            }
            .onChange(of: aiSettings) { _, newValue in
                guard isLoaded else { return }
                aiSettingsSaveTask?.cancel()
                aiSettingsSaveTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    do {
                        try await AIProviderSettingsRepository.update(newValue)
                        saveError = nil
                    } catch { saveError = "Your AI settings couldn’t be saved. Please retry." }
                }
            }
            .onChange(of: apiKey) { _, newValue in
                guard isLoaded else { return }
                apiKeySaveTask?.cancel()
                apiKeySaveTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    KeychainStore.set(newValue, for: .aiProviderAPIKey)
                }
            }
        }
    }

    /// Loads persisted state from the database/Keychain into local `@State`.
    /// Also called after dev tools seed/wipe data, so the form reflects the
    /// change immediately instead of showing stale values.
    private func reload() async {
        isLoaded = false
        do {
            profile = try await UserProfileRepository.current()
            aiSettings = try await AIProviderSettingsRepository.current()
        } catch {
            saveError = "Couldn’t load settings. Reopen Settings to try again."
            return
        }
        apiKey = KeychainStore.get(.aiProviderAPIKey) ?? ""
        // Only start persisting once values are in place, so loading
        // existing settings doesn't immediately re-save them.
        isLoaded = true
    }

    // MARK: - Metabolic target

    private var metabolicTargetSection: some View {
        Section {
            if let profileValidation {
                Label(profileValidation, systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(Color.solaceDestructive)
            }
            if let targets = NutritionTargetCalculator.targets(for: profile) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DAILY TARGET").font(.solaceCaption).foregroundStyle(.secondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(targets.calorieKcal, format: .number)
                                .font(.system(.title, weight: .bold))
                                .tabularNumbers()
                            Text("kcal").font(.solaceBodyMd).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(Color.solaceVitality)
                }
                .padding(.vertical, Spacing.xs)
            }

            LabeledContent("Custom target (kcal)") {
                TextField("Optional", value: $profile.dailyCalorieTargetOverride, format: .number.grouping(.never))
                    .focused($focusedField, equals: .target)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("settings.target")
            }
            if profile.dailyCalorieTargetOverride != nil {
                Button("Use calculated target instead") { profile.dailyCalorieTargetOverride = nil }
            }

            Picker("Sex", selection: Binding(get: { profile.sex ?? "" }, set: { profile.sex = $0.isEmpty ? nil : $0 })) {
                Text("Not set").tag("")
                Text("Male").tag("male")
                Text("Female").tag("female")
            }
            LabeledContent("Birth Year") {
                TextField("e.g. 1996", value: $profile.birthYear, format: .number.grouping(.never))
                    .focused($focusedField, equals: .birthYear)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Height (cm)") {
                TextField("e.g. 175", value: $profile.heightCm, format: .number)
                    .focused($focusedField, equals: .height)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Weight (kg)") {
                TextField("e.g. 70", value: $profile.weightKg, format: .number)
                    .focused($focusedField, equals: .weight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            Picker(
                "Activity Level",
                selection: Binding(get: { profile.activityLevel ?? "" }, set: { profile.activityLevel = $0.isEmpty ? nil : $0 })
            ) {
                Text("Not set").tag("")
                Text("Sedentary").tag("sedentary")
                Text("Light").tag("light")
                Text("Moderate").tag("moderate")
                Text("Active").tag("active")
                Text("Very Active").tag("veryActive")
            }
        } header: {
            Label("Metabolic Target", systemImage: "flame.fill")
        } footer: {
            Text("A custom target takes priority. Otherwise, an estimated target uses your birth year, height, weight, and activity. You can log food without a target.")
        }
    }

    // MARK: - Scoring weights

    private var scoringWeightsSection: some View {
        Section {
            weightSlider("Nutri-Score", value: $profile.nutriScoreWeight, tint: .solaceVitality)
            weightSlider("NOVA", value: $profile.novaWeight, tint: .solaceWarning)
            weightSlider("Eco-Score", value: $profile.ecoScoreWeight, tint: .solaceInteractive)
            weightSlider("Personal Fit", value: $profile.personalGoalWeight, tint: .solaceAI)
        } header: {
            Label("Scoring Weights", systemImage: "chart.pie.fill")
        } footer: {
            let total = profile.nutriScoreWeight + profile.novaWeight + profile.ecoScoreWeight + profile.personalGoalWeight
            HStack {
                Image(systemName: abs(total - 1) < 0.01 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text("Total: \(total, format: .percent.precision(.fractionLength(0)))")
            }
            .foregroundStyle(abs(total - 1) < 0.01 ? Color.solaceVitality : Color.solaceWarning)
        }
    }

    private func weightSlider(_ label: String, value: Binding<Double>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(label).font(.solaceBody)
                Spacer()
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .font(.solaceLabel)
                    .foregroundStyle(.secondary)
                    .tabularNumbers()
            }
            Slider(value: value, in: 0...1, step: 0.05)
                .tint(tint)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Allergens

    private var allergenSection: some View {
        Section {
            if profile.allergenExclusions.isEmpty {
                Text("No allergens excluded.").foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(profile.allergenExclusions, id: \.self) { allergen in
                        RemovableChip(label: allergen.capitalized, tint: .solaceDestructive) {
                            profile.allergenExclusions.removeAll { $0 == allergen }
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            HStack {
                TextField("Add allergen (e.g. Peanuts)", text: $newAllergen)
                    .focused($focusedField, equals: .allergen)
                    .submitLabel(.done)
                    .onSubmit(addAllergen)
                Button("Add", action: addAllergen)
                    .disabled(newAllergen.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Label("Excluded Allergens", systemImage: "exclamationmark.triangle.fill")
        } footer: {
            Text("Any match against a product's allergen tags suppresses its match score and shows a hard warning.")
        }
    }

    private func addAllergen() {
        let trimmed = newAllergen.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !profile.allergenExclusions.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newAllergen = ""
            return
        }
        profile.allergenExclusions.append(trimmed.lowercased())
        newAllergen = ""
    }

    // MARK: - Dietary preferences

    private var dietarySection: some View {
        Section {
            FlowLayout(spacing: Spacing.sm) {
                ForEach(Self.dietaryFlagOptions, id: \.id) { option in
                    SelectableChip(
                        label: option.label,
                        isSelected: profile.dietaryFlags.contains(option.id),
                        tint: .solaceVitality
                    ) {
                        if profile.dietaryFlags.contains(option.id) {
                            profile.dietaryFlags.removeAll { $0 == option.id }
                        } else {
                            profile.dietaryFlags.append(option.id)
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        } header: {
            Label("Dietary Preferences", systemImage: "leaf.fill")
        } footer: {
            Text("Conflicts are detected via ingredient-text keyword matching — a heuristic, not a certified guarantee.")
        }
    }

    private var iCloudStatusLabel: String {
        switch iCloudAccountStatus {
        case .available: return "Automatic"
        case .noAccount: return "Signed Out"
        case .restricted: return "Restricted"
        case .couldNotDetermine, .none: return "Checking…"
        case .temporarilyUnavailable: return "Unavailable"
        @unknown default: return "Unknown"
        }
    }

    private var iCloudStatusColor: Color {
        iCloudAccountStatus == .available ? .secondary : Color.solaceWarning
    }

    private var iCloudStatusFooter: String {
        switch iCloudAccountStatus {
        case .available, .couldNotDetermine, .none:
            return "iCloud sync works when you’re signed into iCloud. Apple Health asks for permission when you next log food with sync enabled."
        default:
            return "Sign in to iCloud in Settings to sync your diary and preferences across devices. Logging still works locally without it."
        }
    }

    // MARK: - Apple ecosystem

    private var appleEcosystemSection: some View {
        Section {
            Toggle(isOn: $profile.healthKitSyncEnabled) {
                Label("Sync Diary to Apple Health", systemImage: "heart.fill")
            }
            LabeledContent {
                Text(iCloudStatusLabel).foregroundStyle(iCloudStatusColor)
            } label: {
                Label("Private iCloud Sync", systemImage: "icloud.fill")
            }
        } header: {
            Label("Apple Ecosystem", systemImage: "applelogo")
        } footer: {
            Text(iCloudStatusFooter)
        }
    }

    // MARK: - AI

    private var aiSection: some View {
        Section {
            Toggle(isOn: $profile.onDeviceAIEnabled) {
                Label("On-Device Score Explanations", systemImage: "sparkles")
                    .foregroundStyle(Color.solaceAI)
            }
        } header: {
            Label("On-device AI", systemImage: "cpu.fill")
        } footer: {
            Text("Score explanations run on your device and require an available Apple Intelligence model.")
        }
    }

    private var aiValidation: String? {
        guard aiSettings.isEnabled else { return nil }
        let trimmed = aiSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed), let host = url.host, !host.isEmpty else {
            return "Enter a valid endpoint URL, e.g. https://api.openai.com/v1."
        }
        guard url.scheme == "https" || ["localhost", "127.0.0.1"].contains(host) else {
            return "The endpoint must use https:// (or be localhost) so your API key isn't sent in plaintext."
        }
        return nil
    }

    private var cloudAISection: some View {
        Section {
            Toggle(isOn: $aiSettings.isEnabled) {
                Label("Enable Cloud AI (Photo Logging)", systemImage: "camera.fill")
            }
            if aiSettings.isEnabled {
                if let aiValidation {
                    Label(aiValidation, systemImage: "exclamationmark.circle")
                        .font(.footnote).foregroundStyle(Color.solaceDestructive)
                }
                LabeledContent("Endpoint") {
                    TextField("https://api.openai.com/v1", text: $aiSettings.baseURL)
                    .focused($focusedField, equals: .endpoint)
                        .submitLabel(.next)
                    .onSubmit { focusedField = .model }
                    .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Model") {
                    TextField("gpt-4o-mini", text: $aiSettings.modelString)
                    .focused($focusedField, equals: .model)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .apiKey }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("API Key") {
                    SecureField("sk-\u{2026}", text: $apiKey)
                    .focused($focusedField, equals: .apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Label("Photo AI", systemImage: "cloud.fill")
        } footer: {
            Text("Your key stays in the Keychain and is sent directly to your provider — never to a Solace server. No key is included with this app.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            Button("Review welcome & setup") { showOnboarding = true }
            LabeledContent("Solace", value: "Free & open source")
            Label("Open Food Facts (ODbL)", systemImage: "checkmark.seal")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
            Label("USDA FoodData Central (public domain)", systemImage: "checkmark.seal")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
        } header: {
            Label("About", systemImage: "info.circle.fill")
        }
    }
}

#Preview {
    SettingsView()
}
