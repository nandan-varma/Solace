//
//  NovaBadge.swift
//  Solace
//

import SwiftUI

/// NOVA processing-classification badge (1 = unprocessed, 4 = ultra-processed).
struct NovaBadge: View {
    let group: Int?

    private var label: String {
        switch group {
        case 1: return "Unprocessed"
        case 2: return "Culinary"
        case 3: return "Processed"
        case 4: return "Ultra-Processed"
        default: return "Unknown"
        }
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("NOVA GROUP")
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
            Text(group.map(String.init) ?? "–")
                .font(.system(.title2, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Color.novaColor(for: group).opacity(0.18))
                .foregroundStyle(Color.novaColor(for: group))
                .clipShape(Circle())
            Text(label)
                .font(.solaceCaption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NovaBadge(group: 3)
}
