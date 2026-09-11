import SwiftUI

/// Optional setup. Preferences are committed together before first-launch completion.
struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var step = 0
    @State private var profile: UserProfile?
    @State private var allergens: Set<String> = []
    @State private var diets: Set<String> = []
    @State private var target = ""
    @State private var isSaving = false
    @State private var error: String?
    @FocusState private var targetFocused: Bool

    private let allergenOptions = ["milk", "eggs", "peanuts", "nuts", "soybeans", "gluten", "fish", "crustaceans", "sesame"]
    private let dietOptions = ["vegan", "vegetarian", "glutenfree", "halal", "kosher"]
    private var validTarget: Bool {
        target.isEmpty || (Int(target).map { (1...10000).contains($0) } ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Capsule().fill(index <= step ? Color.solaceVitality : Color.solaceFill)
                                .frame(height: 4)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Setup, step \(step + 1) of 3")

                    Image(systemName: ["leaf.circle.fill", "slider.horizontal.3", "sun.max.fill"][step])
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(Color.solaceVitality)
                        .padding(20)
                        .background(Color.solaceVitality.opacity(0.1), in: RoundedRectangle(cornerRadius: 28))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(["A little clarity.\nEvery day.", "Make it yours.", "Your pace.\nYour daily target."][step])
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                        Text(["Understand what’s in your food and keep a simple record of what you eat.", "Choose the ingredients you avoid and the preferences that matter to you. Everything here is optional.", "Already have a calorie target? Add it here, or leave it blank and simply log your meals."][step])
                            .foregroundStyle(.secondary)
                    }
                    if step == 0 {
                        VStack(alignment: .leading, spacing: 24) {
                            feature("barcode.viewfinder", "Scan with context", "See nutrition, processing, and ingredient information.")
                            feature("fork.knife", "Build your food diary", "Search for foods and log the portion you actually ate.")
                            feature("chart.bar.fill", "See your week", "Find patterns in your daily energy and macros.")
                        }
                        .padding(20).solaceCard()
                        Text("No account setup required. Photo AI is optional and needs your own provider key.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if step == 1 {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ingredients to avoid").font(.headline)
                            FlowLayout(spacing: 8) {
                                ForEach(allergenOptions, id: \.self) { option in
                                    SelectableChip(label: option.capitalized, isSelected: allergens.contains(option), tint: .solaceVitality) {
                                        toggle(option, in: &allergens)
                                    }
                                }
                            }
                            Text("Dietary preferences").font(.headline).padding(.top, 8)
                            FlowLayout(spacing: 8) {
                                ForEach(dietOptions, id: \.self) { option in
                                    SelectableChip(label: option == "glutenfree" ? "Gluten-free" : option.capitalized, isSelected: diets.contains(option), tint: .solaceVitality) {
                                        toggle(option, in: &diets)
                                    }
                                }
                            }
                            Text("Product information can be incomplete. Always check the package for allergens.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily calories · optional").font(.headline)
                            HStack {
                                TextField("Enter a target", text: $target)
                                    .keyboardType(.numberPad)
                                    .focused($targetFocused)
                                    .accessibilityIdentifier("onboarding.target")
                                Text("kcal").foregroundStyle(.secondary)
                            }
                            .padding(16).background(Color.solaceFill, in: RoundedRectangle(cornerRadius: 12))
                            if !validTarget {
                                Text("Enter a whole number from 1 to 10,000, or leave this blank.")
                                    .font(.footnote).foregroundStyle(Color.solaceDestructive)
                            }
                            Text("You can change this or calculate an estimated target from your body measurements in Settings.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(20).solaceCard()
                        feature("lock.shield", "You choose what to connect", "Apple Health and cloud photo analysis stay off until you enable them in Settings.")
                    }
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Color.solaceDestructive)
                        if profile == nil {
                            Button("Try Again") { Task { await load() } }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .id(step)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.solaceCanvas)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        targetFocused = false
                        if step < 2 { step += 1 } else { Task { await finish() } }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text(step == 2 ? "Start using Solace" : step == 0 ? "Get started" : "Continue")
                            if !isSaving { Image(systemName: "arrow.right") }
                        }
                    }
                    .buttonStyle(.solacePrimary())
                    .accessibilityIdentifier("onboarding.continue")
                    .disabled(profile == nil || isSaving || (step == 2 && !validTarget))
                    if step == 0 {
                        Button("Skip setup") { Task { await finish(skip: true) } }
                            .frame(minHeight: 44)
                            .disabled(profile == nil || isSaving)
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 {
                        Button("Back", systemImage: "chevron.left") { step -= 1 }
                            .disabled(isSaving)
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { targetFocused = false }
                }
            }
            .task { await load() }
        }
    }

    private func feature(_ icon: String, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.solaceVitality)
                .frame(width: 30).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func toggle(_ value: String, in selection: inout Set<String>) {
        if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
    }

    private func load() async {
        do {
            let loaded = try await UserProfileRepository.current()
            profile = loaded
            allergens = Set(loaded.allergenExclusions)
            diets = Set(loaded.dietaryFlags)
            target = loaded.dailyCalorieTargetOverride.map(String.init) ?? ""
            error = nil
        } catch { self.error = "Couldn’t load your preferences. Please try again." }
    }

    private func finish(skip: Bool = false) async {
        guard var profile, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            if !skip {
                guard validTarget else { return }
                profile.allergenExclusions = allergens.sorted()
                profile.dietaryFlags = diets.sorted()
                profile.dailyCalorieTargetOverride = Int(target)
                try await UserProfileRepository.update(profile)
            }
            onComplete()
        } catch { self.error = "Couldn’t save your preferences. Your choices are still here; try again." }
    }
}
