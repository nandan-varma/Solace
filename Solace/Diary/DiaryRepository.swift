//
//  DiaryRepository.swift
//  Solace
//

import Dependencies
import Foundation
import SQLiteData

enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// Writes go through here so every logging path (barcode, search, photo)
/// converges on the same snapshotted `DiaryEntry` shape (Section 6).
enum DiaryRepository {
    static func logProduct(_ product: CachedProduct, quantityGrams: Double, mealSlot: MealSlot) async throws {
        let scale = quantityGrams / 100
        try await insert(
            DiaryEntry(
                id: UUID(),
                loggedAt: Date(),
                mealSlot: mealSlot.rawValue,
                sourceKind: "product",
                sourceBarcode: product.barcode,
                sourceFdcId: nil,
                photoEstimateLabel: nil,
                photoEstimateConfidence: nil,
                quantityGrams: quantityGrams,
                energyKcal: (product.energyKcal100g ?? 0) * scale,
                proteinsG: (product.proteins100g ?? 0) * scale,
                carbohydratesG: (product.carbohydrates100g ?? 0) * scale,
                fatG: (product.fat100g ?? 0) * scale,
                healthKitSampleUUID: nil
            )
        )
    }

    static func logGenericFood(_ food: CachedGenericFood, quantityGrams: Double, mealSlot: MealSlot) async throws {
        let scale = quantityGrams / 100
        try await insert(
            DiaryEntry(
                id: UUID(),
                loggedAt: Date(),
                mealSlot: mealSlot.rawValue,
                sourceKind: "genericFood",
                sourceBarcode: nil,
                sourceFdcId: food.fdcId,
                photoEstimateLabel: nil,
                photoEstimateConfidence: nil,
                quantityGrams: quantityGrams,
                energyKcal: (food.energyKcal100g ?? 0) * scale,
                proteinsG: (food.proteins100g ?? 0) * scale,
                carbohydratesG: (food.carbohydrates100g ?? 0) * scale,
                fatG: (food.fat100g ?? 0) * scale,
                healthKitSampleUUID: nil
            )
        )
    }

    /// Photo estimates are logged as one entry per photo (matching the
    /// "Save total meal" flow), summed across every edited item.
    static func logPhotoEstimate(_ result: PhotoEstimateResult, mealSlot: MealSlot) async throws {
        let label = result.items.map(\.name).joined(separator: ", ")
        try await insert(
            DiaryEntry(
                id: UUID(),
                loggedAt: Date(),
                mealSlot: mealSlot.rawValue,
                sourceKind: "photoEstimate",
                sourceBarcode: nil,
                sourceFdcId: nil,
                photoEstimateLabel: label,
                photoEstimateConfidence: result.confidence,
                quantityGrams: result.items.reduce(0) { $0 + $1.estimatedGrams },
                energyKcal: result.items.reduce(0) { $0 + $1.kcal },
                proteinsG: result.items.reduce(0) { $0 + $1.proteinG },
                carbohydratesG: result.items.reduce(0) { $0 + $1.carbG },
                fatG: result.items.reduce(0) { $0 + $1.fatG },
                healthKitSampleUUID: nil
            )
        )
    }

    private static func insert(_ entry: DiaryEntry) async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try DiaryEntry.insert { entry }.execute(db)
        }
        if let sample = try? await HealthKitManager.shared.write(entry) {
            try await database.write { db in
                try DiaryEntry.find(entry.id).update { $0.healthKitSampleUUID = #bind(sample) }.execute(db)
            }
        }
    }
}
