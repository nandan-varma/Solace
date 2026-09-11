//
//  TodayView.swift
//  Solace
//

import Dependencies
import SQLiteData
import SwiftUI

struct TodayView: View {
    @FetchAll(DiaryEntry.order { $0.loggedAt.desc() }) private var allEntries
    @State private var profile: UserProfile?
    @State private var showSearch = false
    @State private var showPhotoLog = false

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    energySummary
                    macroCards
                    quickEntryRow
                    mealsLog
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("Today")
            .task { profile = try? await UserProfileRepository.current() }
            .sheet(isPresented: $showSearch) { GenericFoodSearchView() }
            .sheet(isPresented: $showPhotoLog) { PhotoLogView() }
        }
    }

    @ViewBuilder
    private var energySummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("DAILY ENERGY").font(.solaceCaption).foregroundStyle(.secondary)
            if let targets {
                HStack(spacing: Spacing.lg) {
                    ScoreRing(
                        progress: targets.calorieKcal > 0 ? totals.kcal / Double(targets.calorieKcal) : 0,
                        tint: .solaceVitality,
                        value: totals.kcal.formatted(.number.precision(.fractionLength(0))),
                        caption: "kcal eaten"
                    )
                    .frame(width: 140, height: 140)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Daily Goal").font(.solaceLabel).foregroundStyle(.secondary)
                        Text("\(targets.calorieKcal) kcal").font(.solaceHeadlineSm)
                        let remaining = max(0, targets.calorieKcal - Int(totals.kcal))
                        Text("\(remaining) kcal left").font(.solaceBodyMd).foregroundStyle(Color.solaceVitality)
                    }
                }
            } else {
                Text("\(Int(totals.kcal)) kcal logged today")
                    .font(.solaceStat())
                Text("Set your profile in Settings to see a daily target.")
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.lg)
        .solaceCard()
    }

    private var macroCards: some View {
        HStack(spacing: Spacing.sm) {
            MacroPill(label: "Protein", color: .solaceProtein, valueGrams: totals.protein, targetGrams: targets?.proteinG)
            MacroPill(label: "Carbs", color: .solaceCarbs, valueGrams: totals.carbs, targetGrams: targets?.carbohydrateG)
            MacroPill(label: "Fat", color: .solaceFat, valueGrams: totals.fat, targetGrams: targets?.fatG)
        }
    }

    private var quickEntryRow: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("QUICK ENTRY").font(.solaceCaption).foregroundStyle(.secondary)
            HStack(spacing: Spacing.sm) {
                NavigationLink {
                    ScanView()
                } label: {
                    Label("Scan", systemImage: "barcode.viewfinder").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.solaceVitality)

                Button { showSearch = true } label: {
                    Label("Search", systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.solaceInteractive)

                Button { showPhotoLog = true } label: {
                    Label("Photo AI", systemImage: "sparkles").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.solaceAI)
            }
        }
    }

    private var mealsLog: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("MEALS LOG").font(.solaceCaption).foregroundStyle(.secondary)
            if todaysEntries.isEmpty {
                Text("Nothing logged yet today.")
                    .font(.solaceBodyMd)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(MealSlot.allCases) { slot in
                    let entries = todaysEntries.filter { $0.mealSlot == slot.rawValue }
                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(slot.displayName).font(.solaceHeadlineSm)
                            ForEach(entries) { entry in
                                DiaryEntryRow(entry: entry)
                            }
                        }
                        .padding(Spacing.md)
                        .solaceCard()
                    }
                }
            }
        }
    }
}

private struct DiaryEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.photoEstimateLabel ?? entry.sourceKind.capitalized)
                    .font(.solaceBody)
                Text("\(Int(entry.quantityGrams))g")
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(entry.energyKcal)) kcal")
                .font(.solaceLabel)
                .tabularNumbers()
        }
    }
}

#Preview {
    TodayView()
}
