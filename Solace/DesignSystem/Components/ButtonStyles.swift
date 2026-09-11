//
//  ButtonStyles.swift
//  Solace
//

import SwiftUI

/// Solid, full-width action button — 50pt tall, 12pt continuous corners,
/// scale-down press feedback. Matches DESIGN.md's "Primary Health Action".
struct SolacePrimaryButtonStyle: ButtonStyle {
    var tint: Color = .solaceVitality
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .background(
                (tint == .solaceVitality ? Color.solaceAction : tint).opacity(isEnabled ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: Corner.md, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Tinted-fill, no-border secondary action. Matches DESIGN.md's "Secondary Action".
struct SolaceSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .solaceInteractive
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(tint.opacity(isEnabled ? 1 : 0.4))
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .background(Color.solaceFill, in: RoundedRectangle(cornerRadius: Corner.md, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SolacePrimaryButtonStyle {
    static func solacePrimary(_ tint: Color = .solaceVitality) -> SolacePrimaryButtonStyle {
        SolacePrimaryButtonStyle(tint: tint)
    }
}

extension ButtonStyle where Self == SolaceSecondaryButtonStyle {
    static func solaceSecondary(_ tint: Color = .solaceInteractive) -> SolaceSecondaryButtonStyle {
        SolaceSecondaryButtonStyle(tint: tint)
    }
}
