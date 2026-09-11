//
//  NutritionTargetCalculatorTests.swift
//  SolaceTests
//

import Foundation
import Testing
@testable import Solace

struct NutritionTargetCalculatorTests {
    @Test func missingInputsYieldNoTarget() {
        let profile = UserProfile(id: UUID())
        #expect(NutritionTargetCalculator.targets(for: profile) == nil)
    }

    @Test func overrideBypassesCalculation() throws {
        var profile = UserProfile(id: UUID())
        profile.dailyCalorieTargetOverride = 2000
        let targets = try #require(NutritionTargetCalculator.targets(for: profile))
        #expect(targets.calorieKcal == 2000)
    }

    @Test func knownMaleExampleMatchesHandCalculation() throws {
        // 30-year-old male, 80kg, 180cm, moderate activity.
        // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        // TDEE = 1780 * 1.55 = 2759
        var profile = UserProfile(id: UUID())
        profile.weightKg = 80
        profile.heightCm = 180
        profile.birthYear = 1996
        profile.sex = "male"
        profile.activityLevel = "moderate"
        let targets = try #require(NutritionTargetCalculator.targets(for: profile, referenceYear: 2026))
        #expect(targets.calorieKcal == 2759)
    }

    @Test func knownFemaleExampleMatchesHandCalculation() throws {
        // 25-year-old female, 60kg, 165cm, sedentary.
        // BMR = 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
        // TDEE = 1345.25 * 1.2 = 1614.3
        var profile = UserProfile(id: UUID())
        profile.weightKg = 60
        profile.heightCm = 165
        profile.birthYear = 2001
        profile.sex = "female"
        profile.activityLevel = "sedentary"
        let targets = try #require(NutritionTargetCalculator.targets(for: profile, referenceYear: 2026))
        #expect(targets.calorieKcal == 1614)
    }

    @Test func macroSplitSumsToApproximatelyTheCalorieTarget() throws {
        var profile = UserProfile(id: UUID())
        profile.weightKg = 70
        profile.heightCm = 170
        profile.birthYear = 1990
        profile.activityLevel = "active"
        let targets = try #require(NutritionTargetCalculator.targets(for: profile, referenceYear: 2026))
        let reconstructedKcal = targets.proteinG * 4 + targets.carbohydrateG * 4 + targets.fatG * 9
        #expect(abs(reconstructedKcal - Double(targets.calorieKcal)) < 1)
    }
}
