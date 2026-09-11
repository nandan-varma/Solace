//
//  ScoringEngineTests.swift
//  SolaceTests
//

import Foundation
import Testing
@testable import Solace

struct ScoringEngineTests {
    private func profile(
        allergens: [String] = [],
        diet: [String] = [],
        weights: (nutri: Double, nova: Double, green: Double, personal: Double) = (0.40, 0.25, 0.15, 0.20)
    ) -> UserProfile {
        var p = UserProfile(id: UUID())
        p.allergenExclusions = allergens
        p.dietaryFlags = diet
        p.nutriScoreWeight = weights.nutri
        p.novaWeight = weights.nova
        p.greenScoreWeight = weights.green
        p.personalGoalWeight = weights.personal
        return p
    }

    @Test func safeProductGetsAMatchScoreAndNoFlags() {
        let food = FoodScoringInput(
            nutriScoreGrade: "a",
            novaGroup: 1,
            greenScoreGrade: "a",
            allergensTags: ["en:milk"],
            proteins100g: 10, sugars100g: 2, fat100g: 1, saturatedFat100g: 0.2, fiber100g: 5, sodium100g: 0.1
        )
        let result = ScoringEngine.evaluate(food, profile: profile())
        #expect(result.safetyFlags.isEmpty)
        #expect(result.matchScore != nil)
        #expect(result.matchScore! > 80)
        #expect(result.breakdown["Nutri-Score"] != nil)
        #expect(result.breakdown["NOVA"] != nil)
        #expect(result.breakdown["Green-Score"] != nil)
        #expect(result.breakdown["Personal Fit"] != nil)
    }

    @Test func allergenHitSuppressesMatchScoreButKeepsBreakdown() {
        let food = FoodScoringInput(
            nutriScoreGrade: "a",
            novaGroup: 1,
            greenScoreGrade: "a",
            allergensTags: ["en:peanuts"]
        )
        let result = ScoringEngine.evaluate(food, profile: profile(allergens: ["Peanuts"]))
        #expect(result.safetyFlags.count == 1)
        #expect(result.matchScore == nil)
        #expect(!result.breakdown.isEmpty, "breakdown must stay available even when the composite is suppressed")
    }

    @Test func dietaryKeywordHeuristicFlagsNonVeganIngredient() {
        let food = FoodScoringInput(ingredientsText: "Water, sugar, whey powder, cocoa")
        let result = ScoringEngine.evaluate(food, profile: profile(diet: ["vegan"]))
        #expect(result.safetyFlags.count == 1)
        #expect(result.matchScore == nil)
    }

    @Test func missingGradesRenormalizeOverAvailableFactors() {
        // USDA generic food: no Nutri-Score/NOVA/Green-Score at all.
        let food = FoodScoringInput(proteins100g: 20, sugars100g: 0, fat100g: 2, saturatedFat100g: 0.5, fiber100g: 3, sodium100g: 0.05)
        let result = ScoringEngine.evaluate(food, profile: profile())
        #expect(result.breakdown.count == 1)
        #expect(result.breakdown["Personal Fit"] != nil)
        #expect(result.matchScore != nil)
        #expect(result.matchScore! >= 0 && result.matchScore! <= 100)
    }

    @Test func worstCaseNutritionClampsToZeroNotNegative() {
        let food = FoodScoringInput(sugars100g: 100, saturatedFat100g: 100, sodium100g: 100)
        let result = ScoringEngine.evaluate(food, profile: profile())
        #expect(result.matchScore! >= 0)
    }
}
