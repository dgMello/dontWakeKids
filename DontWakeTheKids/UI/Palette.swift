import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

/// Pre-dawn palette: deep navy house, warm lamp amber, sticky-note yellow.
enum Palette {
    static let night = UIColor(hex: 0x121729)
    static let wall = UIColor(hex: 0x0A0E1C)
    static let panel = UIColor(hex: 0x1B2140)
    static let line = UIColor(hex: 0x2C3460)
    static let ink = UIColor(hex: 0xE9E7F2)
    static let muted = UIColor(hex: 0x9097B8)
    static let amber = UIColor(hex: 0xF2B65A)
    static let note = UIColor(hex: 0xF5E6A3)
    static let noteInk = UIColor(hex: 0x3A3112)
    static let danger = UIColor(hex: 0xFF6F61)
    static let calm = UIColor(hex: 0x7FB3FF)
    static let skin = UIColor(hex: 0xF0D2B6)
    static let robe = UIColor(hex: 0xC98F3C)
    static let door = UIColor(hex: 0x6B4A2E)

    static func floor(_ room: Room) -> UIColor {
        switch room {
        case .master: return UIColor(hex: 0x2B3256)
        case .baby: return UIColor(hex: 0x2F3460)
        case .bath: return UIColor(hex: 0x24405A)
        case .hall: return UIColor(hex: 0x282E4C)
        case .kid: return UIColor(hex: 0x322F5A)
        case .kitchen: return UIColor(hex: 0x37384A)
        case .living: return UIColor(hex: 0x2D3350)
        }
    }

    /// Blanket color shifts as a kid gets closer to waking.
    static func blanket(for meter: Double) -> UIColor {
        if meter >= 65 { return UIColor(hex: 0xA34A5A) }
        if meter >= 35 { return UIColor(hex: 0x8A6A48) }
        return UIColor(hex: 0x4D5F9A)
    }

    static func meterColor(for meter: Double) -> Color {
        if meter >= 65 { return Color(uiColor: danger) }
        if meter >= 35 { return Color(uiColor: amber) }
        return Color(uiColor: calm)
    }
}

extension Color {
    static let night = Color(uiColor: Palette.night)
    static let panel = Color(uiColor: Palette.panel)
    static let line = Color(uiColor: Palette.line)
    static let ink = Color(uiColor: Palette.ink)
    static let muted = Color(uiColor: Palette.muted)
    static let amber = Color(uiColor: Palette.amber)
    static let note = Color(uiColor: Palette.note)
    static let noteInk = Color(uiColor: Palette.noteInk)
    static let danger = Color(uiColor: Palette.danger)
    static let calm = Color(uiColor: Palette.calm)
}

enum Fonts {
    static func hand(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "ChalkboardSE-Bold" : "ChalkboardSE-Regular", size: size)
    }
}
