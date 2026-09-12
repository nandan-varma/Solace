//
//  ScoreResult.swift
//  Solace
//

import Foundation

struct ScoreResult: Equatable {
    let nutriScoreGrade: String?
    let novaGroup: Int?
    let ecoScoreGrade: String?
    let safetyFlags: [SafetyFlag]
    /// 0-100. `nil` whenever `safetyFlags` is non-empty — never shown
    /// alongside an unresolved safety conflict.
    let matchScore: Int?
    /// Per-factor contribution to `matchScore`, always available even when
    /// `matchScore` itself is suppressed, so the breakdown is one tap away.
    let breakdown: [String: Double]
}
