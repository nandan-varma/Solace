//
//  ScoringEngine.swift
//  Solace
//

import Foundation

/// Pure, synchronous, no I/O. Evaluation order per spec Section 5:
/// 1. Safety check, unconditionally, first — any allergen/diet hit
///    suppresses the composite score regardless of how good it otherwise
///    looks.
/// 2. Nutri-Score/NOVA/Eco-Score pass through unmodified as their own
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
            ecoScoreGrade: food.ecoScoreGrade,
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
            let hit = food.allergensTags.contains { tagMatches(normalize($0), exclusion: normalizedExclusion) }
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
                if let match = keywords.first(where: { keywordMatches($0, in: ingredientsText) }) {
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
        "halal": ["pork", "alcohol", "wine", "gelatin"],
        "kosher": ["pork", "shellfish", "shrimp", "crab", "lobster"],
    ]

    /// Plant-based qualifiers that turn an otherwise-flagged word into a
    /// vegan-friendly ingredient name — "soy milk", "cocoa butter", "peanut
    /// butter" — so flagging every bare mention would misfire on exactly the
    /// vegan/halal-friendly products this check is meant to protect against.
    private static let neutralizingPrecedingWords: [String: Set<String>] = [
        "milk": ["soy", "oat", "almond", "coconut", "rice", "cashew", "pea", "hemp"],
        "butter": ["cocoa", "peanut", "shea", "almond", "cashew", "apple", "sunflower"],
    ]

    /// Whole-word (or whole-word-sequence) match, used instead of plain
    /// substring matching so e.g. "egg" doesn't match "eggplant" and "nuts"
    /// doesn't match "coconuts".
    private static func keywordMatches(_ keyword: String, in text: String) -> Bool {
        let words = text.split(whereSeparator: { !$0.isLetter }).map { $0.lowercased() }
        let needle = keyword.split(separator: " ").map(String.init)
        guard wordSequence(needle, occursIn: words) else { return false }

        return words.indices.contains { start -> Bool in
            guard start + needle.count <= words.count,
                  Array(words[start..<start + needle.count]) == needle
            else { return false }
            // "-free" ingredient-text mentions (alcohol-free, gelatin-free)
            // are the opposite of a conflict — the hyphen is already split
            // into its own word by the tokenizer above.
            let followingWord = start + needle.count < words.count ? words[start + needle.count] : nil
            if followingWord == "free" { return false }
            guard let qualifiers = neutralizingPrecedingWords[keyword] else { return true }
            let precedingWord = start > 0 ? words[start - 1] : nil
            return precedingWord.map { !qualifiers.contains($0) } ?? true
        }
    }

    /// OFF allergen tags are standardized plurals (`en:peanuts`, `en:eggs`,
    /// `en:nuts`) while users naturally type singulars in Settings — so tag
    /// matching tolerates a trailing "s" difference on either side. A false
    /// negative here (missing a real allergen) is the dangerous direction.
    private static func tagMatches(_ tag: String, exclusion: String) -> Bool {
        wordSequence(
            exclusion.split(separator: " ").map(String.init),
            occursIn: tag.split(separator: " ").map(String.init),
            allowPluralVariance: true
        )
    }

    private static func wordSequence(_ needle: [String], occursIn haystack: [String], allowPluralVariance: Bool = false) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            let slice = haystack[start..<start + needle.count]
            let isMatch = allowPluralVariance
                ? zip(slice, needle).allSatisfy(wordsMatch)
                : Array(slice) == needle
            if isMatch { return true }
        }
        return false
    }

    private static func wordsMatch(_ a: String, _ b: String) -> Bool {
        a == b || a + "s" == b || b + "s" == a
    }

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
        if let component = nutriScoreComponent(food.ecoScoreGrade) {
            result["Eco-Score"] = (profile.ecoScoreWeight, profile.ecoScoreWeight * component)
        }
        if let personalFit = personalFitComponent(food) {
            result["Personal Fit"] = (profile.personalGoalWeight, profile.personalGoalWeight * personalFit)
        }

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
    /// a neutral 60-point baseline, clamped to 0...100. `nil` when the food
    /// has no nutrient data at all, so a blank product doesn't get a
    /// confident-looking 60/100 out of thin air.
    private static func personalFitComponent(_ food: FoodScoringInput) -> Double? {
        guard food.proteins100g != nil || food.fiber100g != nil || food.sugars100g != nil
            || food.saturatedFat100g != nil || food.sodium100g != nil
        else { return nil }
        var score = 60.0
        if let protein = food.proteins100g { score += min(20, protein * 0.5) }
        if let fiber = food.fiber100g { score += min(10, fiber * 1.0) }
        if let sugar = food.sugars100g { score -= min(20, sugar * 0.5) }
        if let saturatedFat = food.saturatedFat100g { score -= min(20, saturatedFat * 2.0) }
        if let sodium = food.sodium100g { score -= min(15, sodium * 10.0) }
        return min(100, max(0, score))
    }
}
