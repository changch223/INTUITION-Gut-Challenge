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

    static let bossStages6: [BossID] = [.fog, .shaky, .crush]
    static let bossStagesEndless: [BossID] = [.short, .fog, .shaky, .crush]

    static let difficulties: [(name: String, desc: String)] = [
        ("入門", "標準規則"),
        ("進階", "目標分數 ×1.15"),
        ("老手", "每關少 1 手"),
        ("專家", "開局沒有保命符和道具"),
        ("大師", "每張牌爆炸率 +5%"),
        ("傳說", "商店貴 $1，過關基本獎勵只剩 $2"),
    ]
}

extension BlessingID {
    var name: String {
        switch self {
        case .add: return "加碼"
        case .snow: return "滾雪球"
        case .cool: return "穩手"
        case .gamb: return "賭徒"
        case .hot: return "連勝體質"
        case .grit: return "不屈"
        case .hand: return "多一手"
        case .eye: return "千里眼"
        case .bank: return "利息"
        case .defuse: return "拆彈"
        }
    }

    var desc: String {
        switch self {
        case .add: return "加分牌的分數 +25%，可以重複買"
        case .snow: return "倍數牌的倍率 +0.5，可以重複買"
        case .cool: return "危險 1 格的牌絕對不會爆"
        case .gamb: return "危險 4 格的牌獎勵變 1.5 倍"
        case .hot: return "連中加成上限從 2 倍提高到 3 倍（連中 8 次）"
        case .grit: return "爆炸時連中減半（無條件進位），不會歸零"
        case .hand: return "每關多 1 手，可以重複買"
        case .eye: return "每關開始時送 1 個透視"
        case .bank: return "過關時每持有 $5 多拿 $1，最多 $3"
        case .defuse: return "每關第一次爆炸無效"
        }
    }

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

    /// Playstyle hint shown in the shop.
    var tag: String {
        switch self {
        case .add, .hand: return "任何打法"
        case .snow, .gamb, .defuse: return "高危險大倍數"
        case .cool, .hot, .grit: return "安全連中"
        case .eye: return "魔王關"
        case .bank: return "越早買越好"
        }
    }
}

extension BossID {
    var name: String {
        switch self {
        case .fog: return "濃霧"
        case .crush: return "重壓"
        case .short: return "急迫"
        case .shaky: return "不穩"
        }
    }

    var desc: String {
        switch self {
        case .fog: return "其中一張牌完全蓋住，翻開才知道分數和危險度"
        case .crush: return "爆炸時，這關目前的分數砍半（前面各關不受影響）"
        case .short: return "這關少 2 手"
        case .shaky: return "每張牌爆炸率 +10%"
        }
    }
}

extension ModID {
    var name: String {
        switch self {
        case .heat: return "加溫"
        case .calm: return "平靜"
        case .wild: return "狂野"
        case .lean: return "精簡"
        case .rich: return "豐收"
        case .small: return "穩賺"
        case .fuse: return "短引信"
        case .gold: return "淘金"
        }
    }

    var desc: String {
        switch self {
        case .heat: return "連中加成翻倍：每連中一次得分 +50%（上限不變）"
        case .calm: return "不會出現危險 4 格的牌"
        case .wild: return "倍數牌的出現率加倍"
        case .lean: return "少 1 手，但過關基本獎勵 +$3"
        case .rich: return "剩下的每一手換 $2"
        case .small: return "危險 1 格的牌分數 ×2"
        case .fuse: return "每張牌爆炸率 +8%，加分牌分數 ×1.4"
        case .gold: return "每選中一張牌 +$1"
        }
    }
}

extension ItemID {
    var name: String {
        switch self {
        case .peek: return "透視"
        case .roll: return "重抽"
        case .dbl: return "雙倍"
        case .shield: return "保命符"
        }
    }

    var basePrice: Int {
        switch self {
        case .peek: return 3
        case .roll: return 2
        case .dbl: return 3
        case .shield: return 4
        }
    }
}
