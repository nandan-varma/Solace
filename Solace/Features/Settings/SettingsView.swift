//
//  SettingsView.swift
//  Solace
//

import SwiftUI

/// Profile, targets, scoring weights, allergen/diet safety, and Apple
/// ecosystem toggles. BYOK cloud AI configuration ships in Phase 4 once
/// `OpenAICompatibleClient` exists — this screen only covers Tier 1
/// (on-device) for now.
struct SettingsView: View {
    @State private var profile = UserProfile(id: UUID())
    @State private var newAllergen = ""

    private static let knownDietaryFlags = ["vegan", "vegetarian", "glutenfree", "halal", "kosher"]

    var body: some View {
        NavigationStack {
            Form {
                bodyStatsSection
                scoringWeightsSection
                allergenSection
                dietarySection
                appleEcosystemSection
                aiSection
                aboutSection
            }
            .navigationTitle("Settings")
            .task { if let loaded = try? await UserProfileRepository.current() { profile = loaded } }
            .onChange(of: profile) { _, newValue in
                Task { try? await UserProfileRepository.update(newValue) }
            }
        }
    }

    private var bodyStatsSection: some View {
        Section("Metabolic Target") {
            Picker("Sex", selection: Binding(get: { profile.sex ?? "" }, set: { profile.sex = $0.isEmpty ? nil : $0 })) {
                Text("Not set").tag("")
                Text("Male").tag("male")
                Text("Female").tag("female")
            }
            HStack {
                Text("Birth Year")
                Spacer()
                TextField("e.g. 1996", value: $profile.birthYear, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Height (cm)")
                Spacer()
                TextField("e.g. 175", value: $profile.heightCm, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Weight (kg)")
                Spacer()
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
            if let targets = NutritionTargetCalculator.targets(for: profile) {
                LabeledContent("Computed Target", value: "\(targets.calorieKcal) kcal/day")
            }
        }
    }

    private var scoringWeightsSection: some View {
        Section {
            weightSlider("Nutri-Score", value: $profile.nutriScoreWeight)
            weightSlider("NOVA", value: $profile.novaWeight)
            weightSlider("Green-Score", value: $profile.greenScoreWeight)
            weightSlider("Personal Fit", value: $profile.personalGoalWeight)
        } header: {
            Text("Scoring Weights")
        } footer: {
            let total = profile.nutriScoreWeight + profile.novaWeight + profile.greenScoreWeight + profile.personalGoalWeight
            Text("Total: \(total, format: .percent.precision(.fractionLength(0)))")
                .foregroundStyle(abs(total - 1) < 0.01 ? Color.solaceVitality : Color.solaceWarning)
        }
    }

    private func weightSlider(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1, step: 0.05)
        }
    }

    private var allergenSection: some View {
        Section("Excluded Allergens") {
            ForEach(profile.allergenExclusions, id: \.self) { allergen in
                HStack {
                    Text(allergen.capitalized)
                    Spacer()
                    Button(role: .destructive) {
                        profile.allergenExclusions.removeAll { $0 == allergen }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                TextField("Add allergen (e.g. Peanuts)", text: $newAllergen)
                Button("Add") {
                    let trimmed = newAllergen.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    profile.allergenExclusions.append(trimmed)
                    newAllergen = ""
                }
                .disabled(newAllergen.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var dietarySection: some View {
        Section {
            ForEach(Self.knownDietaryFlags, id: \.self) { flag in
                Toggle(flag.capitalized, isOn: Binding(
                    get: { profile.dietaryFlags.contains(flag) },
                    set: { isOn in
                        if isOn { profile.dietaryFlags.append(flag) }
                        else { profile.dietaryFlags.removeAll { $0 == flag } }
                    }
                ))
            }
        } header: {
            Text("Dietary Preferences")
        } footer: {
            Text("Conflicts are detected via ingredient-text keyword matching — a heuristic, not a certified guarantee.")
        }
    }

    private var appleEcosystemSection: some View {
        Section("Apple Ecosystem") {
            Toggle("Sync Diary to Apple Health", isOn: $profile.healthKitSyncEnabled)
            Text("Private iCloud Sync: On (no paywall)").foregroundStyle(.secondary)
        }
    }

    private var aiSection: some View {
        Section {
            Toggle("On-Device Score Explanations", isOn: $profile.onDeviceAIEnabled)
        } header: {
            Text("AI — Tier 1 (On-Device)")
        } footer: {
            Text("Private & offline, powered by Apple Foundation Models. Cloud AI (photo logging) configuration ships in a later update.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Solace", value: "Free & open source")
            Text("Nutrition data from Open Food Facts (ODbL) and USDA FoodData Central.")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
