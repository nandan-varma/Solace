//
//  Colors.swift
//  Solace
//

import SwiftUI

/// Semantic color tokens, derived from `solace_design_files.zip`'s DESIGN.md.
/// Built on Apple system colors so Dark Mode / increased-contrast / Dynamic Type
/// all work for free, rather than pinning fixed hex values.
extension Color {
    // MARK: Canvas & surfaces
    static let solaceCanvas = Color(.systemGroupedBackground)
    static let solaceCard = Color(.secondarySystemGroupedBackground)
    static let solaceFill = Color(.tertiarySystemFill)

    // MARK: Semantic accents
    static let solaceVitality = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.82, blue: 0.59, alpha: 1)
            : UIColor(red: 0.10, green: 0.40, blue: 0.27, alpha: 1)
    })
    static let solaceAction = Color(red: 0.10, green: 0.40, blue: 0.27)      // optimal alignment, primary action
    static let solaceInteractive = Color(.systemBlue)    // links, nav, calorie ring
    static let solaceAI = Color(.systemIndigo)           // on-device / cloud AI features
    static let solaceWarning = Color(.systemOrange)      // sodium, sugar, allergen caution
    static let solaceDestructive = Color(.systemRed)     // hard allergen alerts, delete

    // MARK: Macro chip colors
    static let solaceCarbs = Color(.systemBlue)
    static let solaceProtein = Color(.systemGreen)
    static let solaceFat = Color(.systemOrange)

    // MARK: Nutri-Score — certified EU palette, never restyle
    static func nutriScoreColor(for grade: String?) -> Color {
        switch grade?.lowercased() {
        case "a": return Color(red: 0x03 / 255, green: 0x81 / 255, blue: 0x41 / 255)
        case "b": return Color(red: 0x85 / 255, green: 0xBB / 255, blue: 0x2F / 255)
        case "c": return Color(red: 0xFE / 255, green: 0xCB / 255, blue: 0x02 / 255)
        case "d": return Color(red: 0xEE / 255, green: 0x81 / 255, blue: 0x00 / 255)
        case "e": return Color(red: 0xE6 / 255, green: 0x3E / 255, blue: 0x11 / 255)
        default: return .secondary
        }
    }

    // MARK: NOVA — certified palette, never restyle
    static func novaColor(for group: Int?) -> Color {
        switch group {
        case 1: return Color(red: 0x00 / 255, green: 0xA8 / 255, blue: 0x59 / 255)
        case 2: return Color(red: 0xFF / 255, green: 0xCC / 255, blue: 0x00 / 255)
        case 3: return Color(red: 0xFF / 255, green: 0x99 / 255, blue: 0x00 / 255)
        case 4: return Color(red: 0xEE / 255, green: 0x3B / 255, blue: 0x24 / 255)
        default: return .secondary
        }
    }

    // MARK: Eco-Score — no certified hex published; reuses the Nutri-Score
    // scale since both are letter-graded environmental/nutrition scores.
    // OFF's Eco-Score can also return "f" (below Nutri-Score's a-e range),
    // so that's handled explicitly rather than falling through to gray.
    static func ecoScoreColor(for grade: String?) -> Color {
        if grade?.lowercased() == "f" {
            return Color(red: 0xB0 / 255, green: 0x1E / 255, blue: 0x0A / 255)
        }
        return nutriScoreColor(for: grade)
    }
}
