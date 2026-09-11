//
//  CachedProduct.swift
//  Solace
//

import Foundation
import SQLiteData

/// Open Food Facts product cache, keyed by barcode. Reference data — never
/// synced via CloudKit, refetched/refreshed independently per device.
@Table("cachedProducts")
nonisolated struct CachedProduct: Codable, Identifiable, Sendable {
    @Column(primaryKey: true) var barcode: String
    var name: String?
    var brands: String?
    var nutriscoreGrade: String?           // "a".."e"
    var nutriscoreVersion: String?         // "2021" | "2024" — see ARCHITECTURE.md risks
    var novaGroup: Int?                     // 1..4
    var greenScoreGrade: String?
    var energyKcal100g: Double?
    var proteins100g: Double?
    var carbohydrates100g: Double?
    var sugars100g: Double?
    var fat100g: Double?
    var saturatedFat100g: Double?
    var fiber100g: Double?
    var sodium100g: Double?
    var allergensTagsJSON: String = "[]"
    var ingredientsText: String?
    var imageURL: String?
    var fetchedAt: Date

    var id: String { barcode }

    var allergensTags: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(allergensTagsJSON.utf8))) ?? []
    }
}
