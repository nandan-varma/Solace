//
//  ScoringEngine.swift
//  Solace
//

import Foundation

/// Pure, synchronous, no I/O. Evaluation order per spec Section 5:
/// 1. Safety check, unconditionally, first — any allergen/diet hit
///    suppresses the composite score regardless of how good it otherwise
///    looks.
/// 2. Nutri-Score/NOVA/Green-Score pass through unmodified as their own
///    badges.
/// 3. If safe, a weighted composite `matchScore`, with the full breakdown
///    always available even when the composite itself is suppressed.
enum ScoringEngine {
    static func evaluate(_ food: FoodScoringInput, profile: UserProfile) -> ScoreResult {
        let flags = safetyFlags(for: food, profile: profile)
        let breakdown = weightedBreakdown(for: food, profile: profile)
        let totalWeight = breakdown.values.reduce(0) { $0 + $1.weight }
        let matchScore: Int? = flags.isEmpty && totalWeight > 0
            ? Int((breakdown.values.reduce(0) { $0 + $1.contribution } / totalWeight).rounded())
            : nil

        return ScoreResult(
            nutriScoreGrade: food.nutriScoreGrade,
            novaGroup: food.novaGroup,
            greenScoreGrade: food.greenScoreGrade,
            safetyFlags: flags,
            matchScore: matchScore,
            breakdown: breakdown.mapValues(\.contribution)
        )
    }

    // MARK: - Safety

    static func safetyFlags(for food: FoodScoringInput, profile: UserProfile) -> [SafetyFlag] {
        var flags: [SafetyFlag] = []

        for exclusion in profile.allergenExclusions {
            let normalizedExclusion = normalize(exclusion)
            guard !normalizedExclusion.isEmpty else { continue }
            let hit = food.allergensTags.contains { normalize($0).contains(normalizedExclusion) }
            if hit {
                flags.append(
                    SafetyFlag(
                        kind: .allergen(exclusion),
                        description: "Contains \(exclusion.capitalized) — excluded in your profile"
                    )
                )
            }
        }

        if let ingredientsText = food.ingredientsText?.lowercased() {
            for rawFlag in profile.dietaryFlags {
                let flag = rawFlag.lowercased()
                guard let keywords = dietaryConflictKeywords[flag] else { continue }
                if let match = keywords.first(where: { ingredientsText.contains($0) }) {
                    flags.append(
                        SafetyFlag(
                            kind: .dietaryConflict(flag),
                            description:
                                "Possible \(flag) conflict — ingredients mention \"\(match)\" (keyword match, not certified)"
                        )
                    )
                }
            }
        }

        return flags
    }

    private static func normalize(_ tag: String) -> String {
        var t = tag.lowercased()
        if let colonRange = t.range(of: ":") { t.removeSubrange(t.startIndex..<colonRange.upperBound) }
        return t.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static let dietaryConflictKeywords: [String: [String]] = [
        "vegan": ["meat", "chicken", "beef", "pork", "fish", "gelatin", "milk", "cheese", "butter", "egg", "honey", "whey", "casein"],
        "vegetarian": ["meat", "chicken", "beef", "pork", "fish", "gelatin"],
        "glutenfree": ["wheat", "barley", "rye", "malt"],
        "gluten-free": ["wheat", "barley", "rye", "malt"],
        "halal": ["pork", "alcohol", "wine", "gelatin"],
        "kosher": ["pork", "shellfish", "shrimp", "crab", "lobster"],
    ]

    // MARK: - Composite

    private static func weightedBreakdown(
        for food: FoodScoringInput, profile: UserProfile
    ) -> [String: (weight: Double, contribution: Double)] {
        var result: [String: (weight: Double, contribution: Double)] = [:]

        if let component = nutriScoreComponent(food.nutriScoreGrade) {
            result["Nutri-Score"] = (profile.nutriScoreWeight, profile.nutriScoreWeight * component)
        }
        if let component = novaComponent(food.novaGroup) {
            result["NOVA"] = (profile.novaWeight, profile.novaWeight * component)
        }
        if let component = nutriScoreComponent(food.greenScoreGrade) {
            result["Green-Score"] = (profile.greenScoreWeight, profile.greenScoreWeight * component)
        }
        let personalFit = personalFitComponent(food)
        result["Personal Fit"] = (profile.personalGoalWeight, profile.personalGoalWeight * personalFit)

        return result
    }

    private static func nutriScoreComponent(_ grade: String?) -> Double? {
        switch grade?.lowercased() {
        case "a": return 100
        case "b": return 80
        case "c": return 60
        case "d": return 40
        case "e": return 20
        default: return nil
        }
    }

    private static func novaComponent(_ group: Int?) -> Double? {
        switch group {
        case 1: return 100
        case 2: return 75
        case 3: return 50
        case 4: return 25
        default: return nil
        }
    }

    /// Nutrition-based heuristic proxy for "fits your goals", used whenever
    /// there's no certified grade to lean on (e.g. USDA generic foods) and
    /// always factored in even when there is one. Not a certified score —
    /// just protein/fiber reward, sugar/saturated-fat/sodium penalty against
    /// a neutral 60-point baseline, clamped to 0...100.
    private static func personalFitComponent(_ food: FoodScoringInput) -> Double {
        var score = 60.0
        if let protein = food.proteins100g { score += min(20, protein * 0.5) }
        if let fiber = food.fiber100g { score += min(10, fiber * 1.0) }
        if let sugar = food.sugars100g { score -= min(20, sugar * 0.5) }
        if let saturatedFat = food.saturatedFat100g { score -= min(20, saturatedFat * 2.0) }
        if let sodium = food.sodium100g { score -= min(15, sodium * 10.0) }
        return min(100, max(0, score))
    }
}
