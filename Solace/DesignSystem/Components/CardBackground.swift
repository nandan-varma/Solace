//
//  CardBackground.swift
//  Solace
//

import SwiftUI

/// The inset-grouped card surface used throughout the app: flat white fill,
/// 16pt continuous corners, hairline border, no diffuse shadow.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                    .fill(Color.solaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
            )
    }
}

extension View {
    func solaceCard() -> some View {
        modifier(CardBackground())
    }
}
