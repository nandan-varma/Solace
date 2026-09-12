//
//  TodayView.swift
//  Solace
//

import Dependencies
import SQLiteData
import SwiftUI

struct TodayView: View {
    @Environment(TabRouter.self) private var router
    @FetchAll(DiaryEntry.order { $0.loggedAt.desc() }) private var allEntries
    @FetchAll(CachedProduct.all) private var cachedProducts
    @FetchAll(CachedGenericFood.all) private var cachedGenericFoods
    @FetchAll(UserProfile.all) private var profiles
    private var profile: UserProfile? { profiles.first }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var energyRingSize = 128
    @State private var showSearch = false
    @State private var showPhotoLog = false
    @State private var attemptedRefetch: Set<String> = []

    private var todaysEntries: [DiaryEntry] {
        let calendar = Calendar.current
        return allEntries.filter { calendar.isDateInToday($0.loggedAt) }
    }

    private var totals: (kcal: Double, protein: Double, carbs: Double, fat: Double) {
        todaysEntries.reduce(into: (0.0, 0.0, 0.0, 0.0)) { totals, entry in
            totals.0 += entry.energyKcal
            totals.1 += entry.proteinsG
            totals.2 += entry.carbohydratesG
            totals.3 += entry.fatG
        }
    }

    private var targets: NutritionTargets? {
        profile.flatMap { NutritionTargetCalculator.targets(for: $0) }
    }

    private var productNamesByBarcode: [String: String] {
        Dictionary(uniqueKeysWithValues: cachedProducts.map { ($0.barcode, $0.name ?? "Unnamed Product") })
    }

    private var genericFoodNamesByID: [Int: String] {
        Dictionary(uniqueKeysWithValues: cachedGenericFoods.map { ($0.fdcId, $0.description) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline).foregroundStyle(.secondary)
                    energySummary
                    macroCards
                    quickEntryRow
                    mealsLog
                }
                .padding(Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.solaceCanvas)
            .navigationTitle("Today")
            .sheet(isPresented: $showSearch) { GenericFoodSearchView() }
            .sheet(isPresented: $showPhotoLog) { PhotoLogView() }
        }
    }

    // MARK: - Energy hero card

    @ViewBuilder
    private var energySummary: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Label("DAILY ENERGY", systemImage: "bolt.fill")
                    .font(.solaceCaption)
                    .foregroundStyle(Color.solaceVitality)
                Spacer()
                if profile?.dailyCalorieTargetOverride != nil {
                    Text("Custom Target").font(.solaceCaption).foregroundStyle(.secondary)
                } else if targets != nil {
                    Text("Mifflin-St Jeor").font(.solaceCaption).foregroundStyle(.secondary)
                }
            }

            if let targets {
                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.lg)) : AnyLayout(HStackLayout(spacing: Spacing.xl))) {
                    ScoreRing(
                        progress: targets.calorieKcal > 0 ? totals.kcal / Double(targets.calorieKcal) : 0,
                        tint: .solaceVitality,
                        value: totals.kcal.formatted(.number.precision(.fractionLength(0))),
                        caption: "kcal eaten"
                    )
                    .frame(width: min(energyRingSize, 240), height: min(energyRingSize, 240))

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        let remaining = targets.calorieKcal - Int(totals.kcal)
                        HStack(spacing: 4) {
                            Text(abs(remaining), format: .number)
                                .font(.system(.title2, weight: .bold))
                                .tabularNumbers()
                            Text(remaining >= 0 ? "kcal left" : "kcal over")
                                .font(.solaceBodyMd)
                        }
                        .foregroundStyle(remaining >= 0 ? Color.solaceVitality : Color.solaceWarning)

                        HStack {
                            Text("Daily Goal").font(.solaceCaption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(targets.calorieKcal) kcal").font(.solaceLabel)
                        }
                        ProgressView(value: min(totals.kcal / Double(max(targets.calorieKcal, 1)), 1))
                            .tint(.solaceVitality)
                    }
                }
            } else {
                HStack(spacing: Spacing.lg) {
                    VStack {
                        Text(Int(totals.kcal), format: .number)
                            .font(.solaceStat())
                            .tabularNumbers()
                        Text("kcal").font(.solaceCaption).foregroundStyle(.secondary)
                    }
                    .frame(width: 88)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("No daily target yet").font(.solaceHeadlineSm)
                        Text("Log meals at your own pace, or add a daily target in Settings.")
                            .font(.solaceCaption)
                            .foregroundStyle(.secondary)
                        Button("Set a daily target") { router.selected = .settings }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                .fill(Color.solaceVitality.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                .strokeBorder(Color.solaceVitality.opacity(0.15), lineWidth: 1)
        )
    }

    private var macroCards: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Spacing.sm)) : AnyLayout(HStackLayout(spacing: Spacing.sm))) {
            MacroPill(label: "Protein", color: .solaceProtein, valueGrams: totals.protein, targetGrams: targets?.proteinG)
            MacroPill(label: "Carbs", color: .solaceCarbs, valueGrams: totals.carbs, targetGrams: targets?.carbohydrateG)
            MacroPill(label: "Fat", color: .solaceFat, valueGrams: totals.fat, targetGrams: targets?.fatG)
        }
    }

    // MARK: - Quick entry

    private var quickEntryRow: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("QUICK ENTRY").font(.solaceCaption).foregroundStyle(.secondary)
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Spacing.sm)) : AnyLayout(HStackLayout(spacing: Spacing.sm))) {
                Button { router.selected = .scan } label: {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(.solacePrimary(.solaceVitality))

                Button { showSearch = true } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(.solaceSecondary(.solaceInteractive))

                Button { showPhotoLog = true } label: {
                    Label("Photo", systemImage: "camera")
                }
                .buttonStyle(.solaceSecondary(.solaceAI))
                .accessibilityLabel("Photo AI")
            }
        }
    }

    // MARK: - Meals log

    private var mealsLog: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("MEALS LOG").font(.solaceCaption).foregroundStyle(.secondary)
                Spacer()
                Text("\(todaysEntries.count) logged").font(.solaceCaption).foregroundStyle(.secondary)
            }

            if todaysEntries.isEmpty {
                emptyMealsLog
            } else {
                ForEach(MealSlot.allCases) { slot in
                    let entries = todaysEntries.filter { $0.mealSlot == slot.rawValue }
                    if !entries.isEmpty {
                        mealSlotCard(slot: slot, entries: entries)
                    }
                }
            }
        }
    }

    private var emptyMealsLog: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Nothing logged yet")
                .font(.solaceHeadlineSm)
            Text("Start with something you’ve eaten today. Every meal is a fresh start.")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Find a food") { showSearch = true }
                .buttonStyle(.solaceSecondary())
                .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .padding(.horizontal, Spacing.lg)
        .solaceCard()
    }

    private func mealSlotCard(slot: MealSlot, entries: [DiaryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: slot.icon)
                    .foregroundStyle(slot.tint)
                    .frame(width: 20)
                Text(slot.displayName).font(.solaceHeadlineSm)
                Spacer()
                let kcal = entries.reduce(0) { $0 + $1.energyKcal }
                Text("\(Int(kcal)) kcal").font(.solaceLabel).foregroundStyle(.secondary).tabularNumbers()
            }
            .padding(Spacing.md)

            Divider().padding(.leading, Spacing.md + 20 + Spacing.sm)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                DiaryEntryRow(
                    entry: entry,
                    resolvedName: name(for: entry)
                )
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .task(id: entry.id) { await refetchIfNeeded(entry) }
                if index < entries.count - 1 {
                    Divider().padding(.leading, Spacing.md)
                }
            }
        }
        .solaceCard()
    }

    /// A `DiaryEntry` can reference a cache row this device never synced
    /// (e.g. logged on another device via CloudKit) — re-fetch it once so
    /// the row shows a real name instead of a permanent placeholder.
    private func refetchIfNeeded(_ entry: DiaryEntry) async {
        switch entry.sourceKind {
        case "product":
            guard let barcode = entry.sourceBarcode, productNamesByBarcode[barcode] == nil,
                  attemptedRefetch.insert("product:\(barcode)").inserted
            else { return }
            _ = try? await ProductRepository.product(forBarcode: barcode)
        case "genericFood":
            guard let fdcId = entry.sourceFdcId, genericFoodNamesByID[fdcId] == nil,
                  attemptedRefetch.insert("genericFood:\(fdcId)").inserted
            else { return }
            _ = try? await GenericFoodRepository.food(forFdcId: fdcId)
        default:
            break
        }
    }

    private func name(for entry: DiaryEntry) -> String {
        switch entry.sourceKind {
        case "product":
            return entry.sourceBarcode.flatMap { productNamesByBarcode[$0] } ?? "Scanned Product"
        case "genericFood":
            return entry.sourceFdcId.flatMap { genericFoodNamesByID[$0] } ?? "Food"
        default:
            return entry.photoEstimateLabel ?? "Photo Estimate"
        }
    }
}

private struct DiaryEntryRow: View {
    let entry: DiaryEntry
    let resolvedName: String

    private var provenance: (label: String, tint: Color) {
        switch entry.sourceKind {
        case "product": return ("OFF", .solaceVitality)
        case "genericFood": return ("USDA", .solaceInteractive)
        default:
            let confidence = entry.photoEstimateConfidence.map { Int($0 * 100) }
            return (confidence.map { "AI \($0)%" } ?? "AI", .solaceAI)
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(resolvedName)
                    .font(.solaceBody)
                    .lineLimit(2)
                Text("\(Int(entry.quantityGrams))g")
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(provenance.label)
                .font(.solaceCaption)
                .foregroundStyle(provenance.tint)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(provenance.tint.opacity(0.12), in: Capsule())
            Text("\(Int(entry.energyKcal)) kcal")
                .font(.solaceLabel)
                .tabularNumbers()
                .frame(width: 78, alignment: .trailing)
        }
    }
}

#Preview {
    TodayView()
        .environment(TabRouter())
}
