//
//  NutriScoreBadge.swift
//  Solace
//

import SwiftUI

/// Unskinned Nutri-Score A-E tile row. The active grade is full opacity and
/// slightly elevated; inactive letters are muted — matches how the grade is
/// presented on-pack in the EU, deliberately not reskinned per the spec.
struct NutriScoreBadge: View {
    let grade: String?

    private let letters = ["A", "B", "C", "D", "E"]

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("NUTRI-SCORE")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(letters, id: \.self) { letter in
                    let isActive = letter.lowercased() == grade?.lowercased()
                    Text(letter)
                        .font(.system(.callout, weight: .bold))
                        .frame(width: 22, height: 26)
                        .background(Color.nutriScoreColor(for: letter))
                        .foregroundStyle(.white)
                        .opacity(isActive ? 1 : 0.35)
                        .scaleEffect(isActive ? 1.1 : 1)
                }
            }
        }
    }
}

#Preview {
    NutriScoreBadge(grade: "b")
}
