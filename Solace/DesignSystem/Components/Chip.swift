//
//  Chip.swift
//  Solace
//

import SwiftUI

/// A removable pill, used for allergen exclusions.
struct RemovableChip: View {
    let label: String
    let tint: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.solaceLabel)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .accessibilityLabel("Remove \(label)")
        }
        .foregroundStyle(tint)
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

/// A toggleable selection pill, used for dietary preference flags.
struct SelectableChip: View {
    let label: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(label)
                    .font(.solaceLabel)
            }
            .foregroundStyle(isSelected ? .white : tint)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 2)
            .background(isSelected ? tint : tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
