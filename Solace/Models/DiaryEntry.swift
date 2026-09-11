//
//  DiaryEntry.swift
//  Solace
//

import Foundation
import SQLiteData

/// One logged food, synced via CloudKit. Nutrition values are snapshotted at
/// log time and never retroactively recomputed if the source cache updates
/// later — what you saw when you logged it is what stays in your diary.
@Table("diaryEntries")
nonisolated struct DiaryEntry: Codable, Identifiable, Sendable {
    let id: UUID
    var loggedAt: Date
    var mealSlot: String                     // "breakfast" | "lunch" | "dinner" | "snack"
    var sourceKind: String                   // "product" | "genericFood" | "photoEstimate"
    var sourceBarcode: String?
    var sourceFdcId: Int?
    var photoEstimateLabel: String?
    var photoEstimateConfidence: Double?     // 0-1, surfaced to the user, not hidden
    var quantityGrams: Double
    var energyKcal: Double
    var proteinsG: Double
    var carbohydratesG: Double
    var fatG: Double
    var healthKitSampleUUID: UUID?
}
