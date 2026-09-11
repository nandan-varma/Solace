//
//  SettingsView.swift
//  Solace
//

import SwiftUI

/// Profile, targets, scoring weights, allergen/diet safety, Apple ecosystem
/// toggles, and both AI tiers (on-device always available; cloud BYOK
/// opt-in per Section 7).
struct SettingsView: View {
    @State private var profile = UserProfile(id: UUID())
    @State private var newAllergen = ""
    @State private var aiSettings = AIProviderSettings(id: UUID())
    @State private var apiKey = ""
    @State private var isLoaded = false

    @State private var profileSaveTask: Task<Void, Never>?
    @State private var aiSettingsSaveTask: Task<Void, Never>?
    @State private var apiKeySaveTask: Task<Void, Never>?

    private static let dietaryFlagOptions: [(id: String, label: String)] = [
        ("vegan", "Vegan"), ("vegetarian", "Vegetarian"), ("glutenfree", "Gluten-Free"),
        ("halal", "Halal"), ("kosher", "Kosher"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                metabolicTargetSection
                scoringWeightsSection
                allergenSection
                dietarySection
                appleEcosystemSection
                aiSection
                cloudAISection
                #if DEBUG
                    DevSettingsSection(onDataChanged: reload)
                #endif
                aboutSection
            }
            .navigationTitle("Settings")
            .task { await reload() }
            .onChange(of: profile) { _, newValue in
                guard isLoaded else { return }
                profileSaveTask?.cancel()
                profileSaveTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    try? await UserProfileRepository.update(newValue)
                }
            }
            .onChange(of: aiSettings) { _, newValue in
                guard isLoaded else { return }
                aiSettingsSaveTask?.cancel()
                aiSettingsSaveTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    try? await AIProviderSettingsRepository.update(newValue)
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
        if let loaded = try? await UserProfileRepository.current() { profile = loaded }
        if let loadedAI = try? await AIProviderSettingsRepository.current() { aiSettings = loadedAI }
        apiKey = KeychainStore.get(.aiProviderAPIKey) ?? ""
        // Only start persisting once values are in place, so loading
        // existing settings doesn't immediately re-save them.
        isLoaded = true
    }

    // MARK: - Metabolic target

    private var metabolicTargetSection: some View {
        Section {
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

            Picker("Sex", selection: Binding(get: { profile.sex ?? "" }, set: { profile.sex = $0.isEmpty ? nil : $0 })) {
                Text("Not set").tag("")
                Text("Male").tag("male")
                Text("Female").tag("female")
            }
            LabeledContent("Birth Year") {
                TextField("e.g. 1996", value: $profile.birthYear, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Height (cm)") {
                TextField("e.g. 175", value: $profile.heightCm, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Weight (kg)") {
                TextField("e.g. 70", value: $profile.weightKg, format: .number)
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
            Text("Computed via Mifflin-St Jeor. Any field left blank simply means the target stays hidden until it's filled in.")
        }
    }

    // MARK: - Scoring weights

    private var scoringWeightsSection: some View {
        Section {
            weightSlider("Nutri-Score", value: $profile.nutriScoreWeight, tint: .solaceVitality)
            weightSlider("NOVA", value: $profile.novaWeight, tint: .solaceWarning)
            weightSlider("Green-Score", value: $profile.greenScoreWeight, tint: .solaceInteractive)
            weightSlider("Personal Fit", value: $profile.personalGoalWeight, tint: .solaceAI)
        } header: {
            Label("Scoring Weights", systemImage: "chart.pie.fill")
        } footer: {
            let total = profile.nutriScoreWeight + profile.novaWeight + profile.greenScoreWeight + profile.personalGoalWeight
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
        profile.allergenExclusions.append(trimmed)
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

    // MARK: - Apple ecosystem

    private var appleEcosystemSection: some View {
        Section {
            Toggle(isOn: $profile.healthKitSyncEnabled) {
                Label("Sync Diary to Apple Health", systemImage: "heart.fill")
            }
            LabeledContent {
                Text("On").foregroundStyle(Color.solaceVitality)
            } label: {
                Label("Private iCloud Sync", systemImage: "icloud.fill")
            }
        } header: {
            Label("Apple Ecosystem", systemImage: "applelogo")
        } footer: {
            Text("iCloud sync is always on — there's no paywall in this app, ever.")
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
            Label("AI \u{00b7} Tier 1 (On-Device)", systemImage: "cpu.fill")
        } footer: {
            Text("Private & offline, powered by Apple Foundation Models. Zero scan history ever leaves this device.")
        }
    }

    private var cloudAISection: some View {
        Section {
            Toggle(isOn: $aiSettings.isEnabled) {
                Label("Enable Cloud AI (Photo Logging)", systemImage: "camera.fill")
            }
            if aiSettings.isEnabled {
                LabeledContent("Endpoint") {
                    TextField("https://api.openai.com/v1", text: $aiSettings.baseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Model") {
                    TextField("gpt-4o-mini", text: $aiSettings.modelString)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("API Key") {
                    SecureField("sk-\u{2026}", text: $apiKey)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Label("AI \u{00b7} Tier 2 (Cloud, BYOK)", systemImage: "cloud.fill")
        } footer: {
            Text("Your key stays in the Keychain and is sent directly to your provider — never to a Solace server. No key is included with this app.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
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
