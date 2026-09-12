//
//  EcoScoreBadge.swift
//  Solace
//

import SwiftUI

/// Eco-Score (environmental impact) badge. Same A-E scale as Nutri-Score,
/// shown as a filled circle per Open Food Facts' on-pack presentation.
struct EcoScoreBadge: View {
    let grade: String?

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("ECO-SCORE")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
            Text(grade?.uppercased() ?? "–")
                .font(.system(.title2, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Color.ecoScoreColor(for: grade))
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
    }
}

#Preview {
    EcoScoreBadge(grade: "a")
}
