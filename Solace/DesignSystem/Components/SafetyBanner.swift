//
//  SafetyBanner.swift
//  Solace
//

import SwiftUI

/// The first thing shown on a product/food evaluation: either a "verified
/// safe" confirmation or the allergen/diet conflicts that suppress the
/// composite match score, per the spec's safety-check-first evaluation order.
struct SafetyBanner: View {
    let flags: [SafetyFlag]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: flags.isEmpty ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(flags.isEmpty ? Color.solaceVitality : Color.solaceDestructive)
                VStack(alignment: .leading, spacing: 2) {
                    Text(flags.isEmpty ? "No conflicts found" : "Conflicts With Your Profile")
                        .font(.solaceHeadlineSm)
                    Text(flags.isEmpty
                         ? "Based on available product data and your preferences. Always check the package for allergens."
                         : flags.map(\.description).joined(separator: ", "))
                        .font(.solaceBodyMd)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                .fill((flags.isEmpty ? Color.solaceVitality : Color.solaceDestructive).opacity(0.12))
        )
    }
}

#Preview {
    SafetyBanner(flags: [])
        .padding()
}
