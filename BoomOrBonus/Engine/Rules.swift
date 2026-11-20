//
//  Rules.swift
//  BoomOrBonus
//
//  Constants and definitions. Values copied from docs/redesign/reference/core.js.
//  Do not change any number here without updating core.js and the test vectors first.
//

import Foundation

enum Rules {
    static let P: [Double] = [0.10, 0.25, 0.42, 0.60]
    static let ADD: [Double] = [3, 5, 7, 10]
    static let MUL: [Double] = [0, 1.5, 2, 3]
    static let PICKS = 7
    static let STAGES = 6
    static let STR = 1.5
    static let TGT: [Double] = [18, 34, 56, 80, 145, 240]
    static let EG = 1.25
    static let DAILY_TM = 1.3
    static let MAX_BLESSINGS = 5

    /// JavaScript Math.round for the values used here (floor(x + 0.5)).
    static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

    /// Overflow guard for very long endless runs (far beyond any real play): scores, deltas and
    /// targets are clamped to 1e18 (< Int.max ~9.22e18). Nothing below that point changes.
    static let SCORE_CAP = 1_000_000_000_000_000_000

    /// Double -> Int without trapping: NaN -> 0, anything beyond +-SCORE_CAP is clamped.
    static func clampScore(_ x: Double) -> Int {
        if x.isNaN { return 0 }
        if x >= Double(SCORE_CAP) { return SCORE_CAP }
        if x <= -Double(SCORE_CAP) { return -SCORE_CAP }
        return Int(x)
    }

    /// a + b, held at SCORE_CAP (stage score).
    static func saturatingScore(_ a: Int, _ b: Int) -> Int {
        min(saturatingAdd(a, b), SCORE_CAP)
    }

    /// a + b, held at Int.max / Int.min instead of trapping (run total).
    static func saturatingAdd(_ a: Int, _ b: Int) -> Int {
        let (r, overflow) = a.addingReportingOverflow(b)
        return overflow ? (b > 0 ? Int.max : Int.min) : r
    }

    static let bossStages6: [BossID] = [.fog, .shaky, .crush]
    static let bossStagesEndless: [BossID] = [.short, .fog, .shaky, .crush]

    /// The six difficulty levels (0...5). Their names and rule texts are presentation: Game/RulesDisplay.swift.
    static let difficulties: [Int] = Array(0..<6)
}

extension BlessingID {
    var basePrice: Int {
        switch self {
        case .add: return 4
        case .snow: return 6
        case .cool: return 5
        case .gamb: return 5
        case .hot: return 6
        case .grit: return 5
        case .hand: return 6
        case .eye: return 5
        case .bank: return 4
        case .defuse: return 7
        }
    }

    var stackable: Bool {
        switch self {
        case .add, .snow, .hand: return true
        default: return false
        }
    }
}

extension ItemID {
    var basePrice: Int {
        switch self {
        case .peek: return 3
        case .roll: return 2
        case .dbl: return 3
        case .shield: return 4
        }
    }
}
