import SwiftUI
import UIKit

/// Ebb's "soft modern" look: white background, plum accent, light lavender
/// cards. Every color adapts to Dark Mode.
enum Theme {
    static let accent = Color(light: 0x7B5EA7, dark: 0xB89BE6)
    static let accentSoft = Color(light: 0xE9E1F5, dark: 0x3A2F4D)
    static let background = Color(light: 0xFFFFFF, dark: 0x121014)
    static let card = Color(light: 0xF6F2FB, dark: 0x1F1A26)
    static let cardBorder = Color(light: 0xEBE4F4, dark: 0x2C2535)
    static let textPrimary = Color(light: 0x2B2B2E, dark: 0xF2EEF7)
    static let textSecondary = Color(light: 0x6B6873, dark: 0xA9A3B3)
    static let positive = Color(light: 0x3E8E6B, dark: 0x6BC49D)
    static let warning = Color(light: 0xB5652B, dark: 0xE39A62)

    /// Colors for severity 0...3.
    static func severityColor(_ value: Int) -> Color {
        switch value {
        case 1: return Color(light: 0xD3C4EC, dark: 0x5A4877)
        case 2: return Color(light: 0xA88AD6, dark: 0x8A6DBB)
        case 3: return Color(light: 0x6A4A9E, dark: 0xC4A8F0)
        default: return Color(light: 0xEFEBF4, dark: 0x2A2431)
        }
    }

    /// Heatmap color for a 0...100 score (nil = not logged).
    static func scoreColor(_ score: Double?) -> Color {
        guard let score else { return Color(light: 0xF4F2F7, dark: 0x1B1820) }
        if score < 1 { return Color(light: 0xE6F2EC, dark: 0x1F3A2E) }
        let level = min(max(Int((score / 100 * 3).rounded(.up)), 1), 3)
        return severityColor(level)
    }

    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    static let spacing: CGFloat = 16
}

extension Color {
    /// A color that switches between two hex values for light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
