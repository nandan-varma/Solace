//
//  HistoryView.swift
//  Solace
//

import Charts
import SQLiteData
import SwiftUI

/// Secondary trends tab (Section 10) — a week of daily calorie totals.
struct HistoryView: View {
    @FetchAll(DiaryEntry.order { $0.loggedAt.desc() }) private var allEntries
    @FetchAll(UserProfile.all) private var profiles
    private var profile: UserProfile? { profiles.first }
    @State private var showSearch = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct DayTotal: Identifiable {
        let day: Date
        var kcal: Double
        var isToday: Bool
        var id: Date { day }
    }

    private var lastSevenDays: [DayTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).reversed().map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        return days.map { day in
            let kcal = allEntries
                .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.energyKcal }
            return DayTotal(day: day, kcal: kcal, isToday: calendar.isDateInToday(day))
        }
    }

    private var daysLogged: Int { lastSevenDays.filter { $0.kcal > 0 }.count }
    private var weekTotal: Double { lastSevenDays.reduce(0) { $0 + $1.kcal } }
    private var dailyAverage: Double { daysLogged > 0 ? weekTotal / Double(daysLogged) : 0 }
    private var target: NutritionTargets? { profile.flatMap { NutritionTargetCalculator.targets(for: $0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Your last seven days")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if daysLogged == 0 {
                        ContentUnavailableView(
                            "No History Yet",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Log a few meals and your weekly trends will show up here.")
                        )
                        .padding(.top, Spacing.xl)
                        Button("Log your first food") { showSearch = true }
                            .buttonStyle(.solacePrimary())
                    } else {
                        summaryStats
                        chartCard
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.solaceCanvas)
            .navigationTitle("Trends")
            .sheet(isPresented: $showSearch) { GenericFoodSearchView() }
        }
    }

    private var summaryStats: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Spacing.sm)) : AnyLayout(HStackLayout(spacing: Spacing.sm))) {
            statTile(title: "Weekly Total", value: "\(Int(weekTotal))", unit: "kcal")
            statTile(title: "Daily Average", value: "\(Int(dailyAverage))", unit: "kcal")
            statTile(title: "Days Logged", value: "\(daysLogged)", unit: "/ 7")
        }
    }

    private func statTile(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased()).font(.solaceCaption).foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value).font(.system(.title3, weight: .bold)).tabularNumbers()
                Text(unit).font(.solaceCaption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .solaceCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("CALORIES · LAST 7 DAYS").font(.solaceCaption).foregroundStyle(.secondary)

            Chart {
                ForEach(lastSevenDays) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("kcal", day.kcal)
                    )
                    .foregroundStyle(day.isToday ? Color.solaceVitality : Color.solaceVitality.opacity(0.35))
                    .cornerRadius(4)
                }
                if let target, target.calorieKcal > 0 {
                    RuleMark(y: .value("Target", target.calorieKcal))
                        .foregroundStyle(Color.solaceInteractive)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal").font(.solaceCaption).foregroundStyle(Color.solaceInteractive)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 200)
            Text("Daily average includes days with logged food only. Unlogged days don’t necessarily mean no food was eaten.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .solaceCard()
    }
}

#Preview {
    HistoryView()
}
