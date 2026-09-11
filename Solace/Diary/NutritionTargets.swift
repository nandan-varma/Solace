//
//  NutritionTargets.swift
//  Solace
//

import Foundation

struct NutritionTargets: Equatable {
    let calorieKcal: Int
    let proteinG: Double
    let carbohydrateG: Double
    let fatG: Double
}

/// Mifflin-St Jeor daily targets (Section 6). Any missing input simply means
/// no target is shown — this never blocks logging.
enum NutritionTargetCalculator {
    private enum ActivityMultiplier {
        static let values: [String: Double] = [
            "sedentary": 1.2,
            "light": 1.375,
            "moderate": 1.55,
            "active": 1.725,
            "veryActive": 1.9,
        ]
    }

    static func targets(for profile: UserProfile, referenceYear: Int = Calendar.current.component(.year, from: Date())) -> NutritionTargets? {
        if let override = profile.dailyCalorieTargetOverride {
            return NutritionTargets(
                calorieKcal: override,
                proteinG: Double(override) * 0.30 / 4,
                carbohydrateG: Double(override) * 0.40 / 4,
                fatG: Double(override) * 0.30 / 9
            )
        }

        guard let weightKg = profile.weightKg,
              let heightCm = profile.heightCm,
              let birthYear = profile.birthYear,
              let activityLevel = profile.activityLevel,
              let multiplier = ActivityMultiplier.values[activityLevel]
        else { return nil }

        let age = Double(referenceYear - birthYear)
        // Mifflin-St Jeor differs by biological sex (+5 male / -161 female);
        // unspecified/other sex uses the midpoint rather than guessing.
        let sexConstant: Double
        switch profile.sex?.lowercased() {
        case "male": sexConstant = 5
        case "female": sexConstant = -161
        default: sexConstant = -78
        }

        let bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + sexConstant
        let calorieKcal = Int((bmr * multiplier).rounded())

        return NutritionTargets(
            calorieKcal: calorieKcal,
            proteinG: Double(calorieKcal) * 0.30 / 4,
            carbohydrateG: Double(calorieKcal) * 0.40 / 4,
            fatG: Double(calorieKcal) * 0.30 / 9
        )
    }
}
