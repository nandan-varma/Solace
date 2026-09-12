//
//  GenericFoodSearchView.swift
//  Solace
//

import SwiftUI

/// Generic/whole food search — always resolves against USDA, per the
/// "prefer verified data over crowd-sourced" principle (Section 1).
/// Searches live as the user types (debounced), not only on keyboard submit.
struct GenericFoodSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @FocusState private var searchFocused: Bool
    @State private var searchPresented = true
    @State private var didFocusSearch = false
    @State private var query = ""
    @State private var results: [CachedGenericFood] = []
    @State private var isSearching = false
    @State private var isPending = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if let searchError {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(searchError).foregroundStyle(.secondary)
                        Button("Try Again") { runSearch(debounced: false) }
                    }
                } else if results.isEmpty && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Search Verified Foods",
                        systemImage: "leaf.fill",
                        description: Text("Search USDA FoodData Central for whole foods like \u{201c}banana, raw\u{201d} or \u{201c}chicken breast\u{201d}.")
                    )
                } else if results.isEmpty && !isSearching && !isPending {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(results) { food in
                    NavigationLink(value: food) {
                        GenericFoodRow(food: food)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Find a food")
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(for: CachedGenericFood.self) { food in
                GenericFoodDetailView(food: food, onDone: { dismiss() })
                    .onAppear { DispatchQueue.main.async { searchFocused = false } }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .searchable(text: $query, isPresented: $searchPresented,
                        placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
            .searchFocused($searchFocused)
            .task {
                guard !didFocusSearch else { return }
                didFocusSearch = true
                // Toggle off/on each attempt: reassigning `true` when it's
                // already `true` is a no-op, so a single delayed assignment
                // can silently miss the moment the search field becomes
                // focusable during the sheet's presentation animation.
                for _ in 0..<10 {
                    searchFocused = false
                    try? await Task.sleep(for: .milliseconds(30))
                    searchFocused = true
                    try? await Task.sleep(for: .milliseconds(60))
                }
            }
            .onDisappear {
                searchTask?.cancel()
                isSearching = false
                isPending = false
            }
            .onChange(of: query) { _, _ in Task { runSearch(debounced: true) } }
            .onSubmit(of: .search) {
                searchFocused = false
                runSearch(debounced: false)
            }
            .overlay {
                if (isSearching || isPending) && results.isEmpty {
                    ProgressView("Searching foods…")
                        .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    /// Debounced so a search fires ~400ms after the user pauses typing,
    /// instead of requiring an explicit keyboard "Search" tap.
    private func runSearch(debounced: Bool) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            searchError = nil
            isPending = false
            isSearching = false
            return
        }
        searchError = nil
        isPending = true
        searchTask = Task {
            if debounced {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
            }
            await search(trimmed)
        }
    }

    private func search(_ trimmed: String) async {
        isPending = false
        isSearching = true
        do {
            let found = try await GenericFoodRepository.search(query: trimmed)
            guard !Task.isCancelled else { return }
            results = found
            searchError = nil
            isSearching = false
        } catch {
            guard !Task.isCancelled else { return }
            searchError = error.localizedDescription
            isSearching = false
        }
    }
}

private struct GenericFoodRow: View {
    let food: CachedGenericFood

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(Color.solaceInteractive.opacity(0.12))
                Image(systemName: "leaf.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.solaceInteractive)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(food.description).font(.solaceBody).lineLimit(2)
                Text(food.dataType == "Foundation" ? "USDA Foundation \u{00b7} Verified" : "USDA SR Legacy \u{00b7} Verified")
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let kcal = food.energyKcal100g {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Int(kcal), format: .number).font(.solaceLabel).tabularNumbers()
                    Text("kcal/100g").font(.solaceCaption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

private struct GenericFoodDetailView: View {
    let food: CachedGenericFood
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Label("USDA FoodData Central", systemImage: "checkmark.seal.fill")
                    .font(.solaceCaption)
                    .foregroundStyle(Color.solaceInteractive)

                HStack(alignment: .top, spacing: Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Corner.sm, style: .continuous)
                            .fill(Color.solaceInteractive.opacity(0.12))
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.solaceInteractive)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(food.description)
                            .font(.solaceHeadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(food.dataType == "Foundation" ? "USDA Foundation Food" : "USDA SR Legacy")
                            .font(.solaceCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("NUTRIENTS \u{00b7} PER 100G").font(.solaceCaption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: Spacing.sm) {
                        MacroPill(label: "Carbs", color: .solaceCarbs, valueGrams: food.carbohydrates100g)
                        MacroPill(label: "Protein", color: .solaceProtein, valueGrams: food.proteins100g)
                        MacroPill(label: "Fat", color: .solaceFat, valueGrams: food.fat100g)
                        MacroPill(label: "Fiber", color: .solaceVitality, valueGrams: food.fiber100g)
                    }
                }

                LogEntryControl(onDone: onDone) { quantity, mealSlot in
                    try await DiaryRepository.logGenericFood(food, quantityGrams: quantity, mealSlot: mealSlot)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal")
                    Text("Data from USDA FoodData Central (public domain)")
                }
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .padding(Spacing.lg)
        }
        .background(Color.solaceCanvas)
        .navigationTitle("Food Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
