//
//  SafetyFlag.swift
//  Solace
//

import Foundation

/// A hard allergen/dietary-conflict hit. Any non-empty set of flags
/// suppresses the composite match score, per the spec's safety-first
/// evaluation order — a decent-looking score should never hide a real
/// allergen.
struct SafetyFlag: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case allergen(String)
        case dietaryConflict(String)
    }

    let kind: Kind
    let description: String
    var id: String { description }
}
