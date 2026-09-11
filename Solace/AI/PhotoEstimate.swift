//
//  PhotoEstimate.swift
//  Solace
//

import Foundation

/// One AI-identified item within a photo estimate. `estimatedGrams` and the
/// macros are the model's best guess for the *whole* portion it saw (not
/// per-100g), so editing the gram count rescales the macros proportionally.
struct PhotoEstimateItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var estimatedGrams: Double
    var kcal: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double

    /// Rates per gram, used to rescale macros as the user adjusts portion size.
    var perGram: (kcal: Double, protein: Double, carb: Double, fat: Double) {
        guard estimatedGrams > 0 else { return (0, 0, 0, 0) }
        return (kcal / estimatedGrams, proteinG / estimatedGrams, carbG / estimatedGrams, fatG / estimatedGrams)
    }
}

struct PhotoEstimateResult: Equatable {
    var items: [PhotoEstimateItem]
    /// 0-1, surfaced to the user per the spec's "never hide the confidence" requirement.
    var confidence: Double
}
