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

    private struct DayTotal: Identifiable {
        let day: Date
        var kcal: Double
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
            return DayTotal(day: day, kcal: kcal)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if allEntries.isEmpty {
                        ContentUnavailableView(
                            "No History Yet",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Log a few meals and your trends will show up here.")
                        )
                        .padding(.top, Spacing.xl)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("CALORIES — LAST 7 DAYS").font(.solaceCaption).foregroundStyle(.secondary)
                            Chart(lastSevenDays) { day in
                                BarMark(
                                    x: .value("Day", day.day, unit: .day),
                                    y: .value("kcal", day.kcal)
                                )
                                .foregroundStyle(Color.solaceVitality)
                            }
                            .frame(height: 200)
                        }
                        .padding(Spacing.lg)
                        .solaceCard()
                    }
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("Trends")
        }
    }
}

#Preview {
    HistoryView()
}
