//
//  FoodScoringInput.swift
//  Solace
//

import Foundation

/// Decouples `ScoringEngine` from the persistence layer: both
/// `CachedProduct` and `CachedGenericFood` convert into this before scoring,
/// which keeps the engine a pure function and easy to unit test with
/// fixtures rather than a live database. All nutrition fields are per-100g,
/// matching the cache tables' convention.
struct FoodScoringInput: Equatable {
    var nutriScoreGrade: String?
    var novaGroup: Int?
    var ecoScoreGrade: String?
    var allergensTags: [String] = []
    var ingredientsText: String?

    var energyKcal100g: Double?
    var proteins100g: Double?
    var carbohydrates100g: Double?
    var sugars100g: Double?
    var fat100g: Double?
    var saturatedFat100g: Double?
    var fiber100g: Double?
    var sodium100g: Double?
}

extension CachedProduct {
    var scoringInput: FoodScoringInput {
        FoodScoringInput(
            nutriScoreGrade: nutriscoreGrade,
            novaGroup: novaGroup,
            ecoScoreGrade: ecoScoreGrade,
            allergensTags: allergensTags,
            ingredientsText: ingredientsText,
            energyKcal100g: energyKcal100g,
            proteins100g: proteins100g,
            carbohydrates100g: carbohydrates100g,
            sugars100g: sugars100g,
            fat100g: fat100g,
            saturatedFat100g: saturatedFat100g,
            fiber100g: fiber100g,
            sodium100g: sodium100g
        )
    }
}

extension CachedGenericFood {
    /// USDA data has no Nutri-Score/NOVA/Eco-Score or allergen tags — those
    /// factors simply don't contribute, and the composite is renormalized
    /// over whatever factors are available.
    var scoringInput: FoodScoringInput {
        FoodScoringInput(
            energyKcal100g: energyKcal100g,
            proteins100g: proteins100g,
            carbohydrates100g: carbohydrates100g,
            fat100g: fat100g,
            fiber100g: fiber100g,
            sodium100g: sodium100g
        )
    }
}
