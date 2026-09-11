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
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Text(label).font(.solaceLabel)
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 44)
            .background(tint.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(label)")
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
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.solaceLabel)
            }
            .foregroundStyle(isSelected ? .white : tint)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 2)
            .frame(minHeight: 44)
            .background(isSelected ? (tint == .solaceVitality ? Color.solaceAction : tint) : tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
