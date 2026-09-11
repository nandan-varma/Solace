//
//  MacroPill.swift
//  Solace
//

import SwiftUI

/// Compact macro readout: colored dot + label + tabular gram count, optionally
/// against a target (used on Today's macro cards and product detail nutrients).
struct MacroPill: View {
    let label: String
    let color: Color
    let valueGrams: Double
    var targetGrams: Double?

    private var progress: Double? {
        guard let target = targetGrams, target > 0 else { return nil }
        return valueGrams / target
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.solaceLabel)
                if let progress {
                    Spacer()
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.solaceLabel)
                        .foregroundStyle(color)
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                Text(valueGrams, format: .number.precision(.fractionLength(0)))
                    .font(.system(.title3, weight: .bold))
                    .tabularNumbers()
                Text("g")
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)
                if let targetGrams {
                    Text("/\(targetGrams.formatted(.number.precision(.fractionLength(0))))g")
                        .font(.solaceCaption)
                        .foregroundStyle(.secondary)
                }
            }
            if let progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(color)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solaceCard()
    }
}

#Preview {
    MacroPill(label: "Protein", color: .solaceProtein, valueGrams: 112, targetGrams: 150)
        .padding()
}
