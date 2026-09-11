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
                } else if results.isEmpty && query.isEmpty {
                    ContentUnavailableView(
                        "Search Verified Foods",
                        systemImage: "magnifyingglass",
                        description: Text("Search USDA FoodData Central for whole foods like \"banana, raw\" or \"chicken breast\".")
                    )
                } else if results.isEmpty && !isSearching && !isPending {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(results) { food in
                    NavigationLink(value: food) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(food.description).font(.solaceBody)
                            HStack(spacing: Spacing.sm) {
                                Text(food.dataType).font(.solaceCaption).foregroundStyle(.secondary)
                                if let kcal = food.energyKcal100g {
                                    Text("\(Int(kcal)) kcal / 100g").font(.solaceCaption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search USDA Database")
            .navigationDestination(for: CachedGenericFood.self) { food in
                GenericFoodDetailView(food: food)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .searchable(text: $query, prompt: "e.g. \"banana, raw\"")
            .onChange(of: query) { _, _ in runSearch(debounced: true) }
            .onSubmit(of: .search) { runSearch(debounced: false) }
            .overlay {
                if isSearching && results.isEmpty { ProgressView() }
            }
        }
    }

    /// Debounced so a search fires ~400ms after the user pauses typing,
    /// instead of requiring an explicit keyboard "Search" tap.
    private func runSearch(debounced: Bool) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            searchError = nil
            isPending = false
            isSearching = false
            return
        }
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

private struct GenericFoodDetailView: View {
    let food: CachedGenericFood

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(food.description).font(.solaceHeadline)
                Text(food.dataType == "Foundation" ? "USDA Foundation Food — verified" : "USDA SR Legacy — verified")
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                    MacroPill(label: "Carbs", color: .solaceCarbs, valueGrams: food.carbohydrates100g ?? 0)
                    MacroPill(label: "Protein", color: .solaceProtein, valueGrams: food.proteins100g ?? 0)
                    MacroPill(label: "Fat", color: .solaceFat, valueGrams: food.fat100g ?? 0)
                    MacroPill(label: "Fiber", color: .solaceVitality, valueGrams: food.fiber100g ?? 0)
                }

                LogEntryControl { quantity, mealSlot in
                    try await DiaryRepository.logGenericFood(food, quantityGrams: quantity, mealSlot: mealSlot)
                }

                Text("Data from USDA FoodData Central (public domain)")
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Food Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
