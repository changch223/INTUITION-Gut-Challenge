//
//  Theme.swift
//  BoomOrBonus
//
//  Design tokens from 02-screens-ux.md §1. The game screen is always the cobalt night
//  look and ignores the system light/dark setting, so every color is hard-coded.
//

import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    static let bgTop = Color(hex: 0x2638DC)
    static let bgMid = Color(hex: 0x131C96)
    static let bgBottom = Color(hex: 0x0B1060)

    static let ink = Color(hex: 0xFFFCF2)
    static let inkMuted = Color(hex: 0xC6CCFF)
    static let inkFaint = Color(hex: 0x9AA3F0)
    static let night = Color(hex: 0x10133A)
    static let deepNight = Color(hex: 0x05071C)   // toast / scrim / ad screen (prototype)

    static let coachScrim = Color(hex: 0x05071C, opacity: 0.8)   // onboarding scrim (prototype .coach .hole)

    static let gold = Color(hex: 0xFFB21E)
    static let goldText = Color(hex: 0x1B1300)    // text on gold (prototype)
    static let mint = Color(hex: 0x16D6A3)
    static let red = Color(hex: 0xFF3B5C)

    static let danger1 = Color(hex: 0x0FA57C)
    static let danger2 = Color(hex: 0xD99A00)
    static let danger3 = Color(hex: 0xF06A1D)
    static let danger4 = Color(hex: 0xF0284B)
    static let fog = Color(hex: 0x8088B8)
    static let fogStripeA = Color(hex: 0xC9CEE8)
    static let fogStripeB = Color(hex: 0xD8DCF0)
    static let shieldSaved = Color(hex: 0xC9D1FF) // "saved" card face (prototype)

    static let sheetBg = Color(hex: 0xFFFCF2)
    static let sheetText = Color(hex: 0x10133A)
    static let sheetMuted = Color(hex: 0x5A6088)
    static let sheetBody = Color(hex: 0x454B74)
    static let sheetButton = Color(hex: 0xE3E5F5)
    static let sheetPrimary = Color(hex: 0x2638DC)

    static func danger(_ d: Int) -> Color {
        switch d {
        case 1: return danger1
        case 2: return danger2
        case 3: return danger3
        default: return danger4
        }
    }

    /// 165deg linear gradient, 0% / 55% / 100%.
    static let background = LinearGradient(
        stops: [
            .init(color: bgTop, location: 0),
            .init(color: bgMid, location: 0.55),
            .init(color: bgBottom, location: 1),
        ],
        startPoint: UnitPoint(x: 0.37, y: 0),
        endPoint: UnitPoint(x: 0.63, y: 1)
    )

    /// Rounded heavy digits, always monospaced (02 §1).
    static func number(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

enum Fmt {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    /// 1,234 style, like prototype fmt().
    static func int(_ n: Int) -> String { formatter.string(from: NSNumber(value: n)) ?? "\(n)" }

    /// 2 -> "2", 1.5 -> "1.5", 1.75 -> "1.75"
    static func num(_ x: Double) -> String {
        let r = (x * 100).rounded() / 100
        if r == r.rounded() { return String(Int(r)) }
        var s = String(format: "%.2f", r)
        while s.hasSuffix("0") { s.removeLast() }
        return s
    }
}
