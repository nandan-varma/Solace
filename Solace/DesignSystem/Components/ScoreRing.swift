//
//  ScoreRing.swift
//  Solace
//

import SwiftUI

/// Circular progress ring used for both the Today energy summary and the
/// product-detail match score. `progress` is clamped to 0...1.
struct ScoreRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 10
    var value: String
    var caption: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: progress)
            VStack(spacing: Spacing.xs) {
                Text(value)
                    .font(.solaceStat())
                    .tabularNumbers()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(caption)
                    .font(.solaceCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
    }
}

#Preview {
    ScoreRing(progress: 0.68, tint: .solaceVitality, value: "1,420", caption: "kcal eaten")
        .frame(width: 180, height: 180)
}
