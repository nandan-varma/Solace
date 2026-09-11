//
//  GenericFoodSearchView.swift
//  Solace
//

import SwiftUI

/// Generic/whole food search — always resolves against USDA, per the
/// "prefer verified data over crowd-sourced" principle (Section 1).
struct GenericFoodSearchView: View {
    @State private var query = ""
    @State private var results: [CachedGenericFood] = []
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        NavigationStack {
            List {
                if let searchError {
                    Text(searchError).foregroundStyle(.secondary)
                } else if results.isEmpty && !query.isEmpty && !isSearching {
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
            .searchable(text: $query, prompt: "e.g. \"banana, raw\"")
            .onSubmit(of: .search) { Task { await search() } }
            .overlay {
                if isSearching { ProgressView() }
            }
        }
    }

    private func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await GenericFoodRepository.search(query: query)
            searchError = results.isEmpty ? "No verified USDA matches for \"\(query)\"." : nil
        } catch {
            searchError = error.localizedDescription
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
