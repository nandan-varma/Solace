//
//  CachedGenericFood.swift
//  Solace
//

import Foundation
import SQLiteData

/// USDA FoodData Central cache, keyed by `fdcId`. Reference data — never
/// synced via CloudKit.
@Table("cachedGenericFoods")
nonisolated struct CachedGenericFood: Codable, Identifiable, Hashable, Sendable {
    @Column(primaryKey: true) var fdcId: Int
    var description: String                 // e.g. "Banana, raw"
    var dataType: String                    // "Foundation" | "SRLegacy" | "Branded" | "Survey"
    var energyKcal100g: Double?
    var proteins100g: Double?
    var carbohydrates100g: Double?
    var fat100g: Double?
    var fiber100g: Double?
    var sodium100g: Double?
    var fetchedAt: Date

    var id: Int { fdcId }
}
