//
//  Typography.swift
//  Solace
//

import SwiftUI

/// Semantic text styles matching DESIGN.md's type scale, mapped onto the
/// native SF Pro / Dynamic Type system font rather than a bundled custom
/// family, so accessibility text sizing keeps working.
extension Font {
    static let solaceDisplay = Font.system(.largeTitle, weight: .bold)
    static let solaceHeadline = Font.system(.title3, weight: .semibold)
    static let solaceHeadlineSm = Font.system(.headline, weight: .semibold)
    static let solaceBody = Font.system(.body)
    static let solaceBodyMd = Font.system(.subheadline)
    static let solaceLabel = Font.system(.footnote, weight: .medium)
    static let solaceCaption = Font.system(.caption2)

    /// Large numeric readouts (kcal counters, ring centers). Tabular figures
    /// keep digits from shifting width as they change.
    static func solaceStat(size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

extension View {
    /// Applies tabular (monospaced) digit rendering for glanceable numeric
    /// alignment, per DESIGN.md's `tabular-nums` requirement.
    func tabularNumbers() -> some View {
        monospacedDigit()
    }
}
