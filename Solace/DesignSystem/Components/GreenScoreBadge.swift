//
//  GreenScoreBadge.swift
//  Solace
//

import SwiftUI

/// Green-Score (environmental impact) badge. Same A-E scale as Nutri-Score,
/// shown as a filled circle per Open Food Facts' on-pack presentation.
struct GreenScoreBadge: View {
    let grade: String?

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("GREEN-SCORE")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
            Text(grade?.uppercased() ?? "–")
                .font(.system(.title2, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Color.greenScoreColor(for: grade))
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
    }
}

#Preview {
    GreenScoreBadge(grade: "a")
}
