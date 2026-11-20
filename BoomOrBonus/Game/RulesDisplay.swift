//
//  RulesDisplay.swift
//  BoomOrBonus
//
//  The player-facing names and texts of the rules, localized here (not in Engine/, which stays UI-agnostic).
//  The keys are the zh-Hant copy, which is the source of truth (docs/redesign/README.md); the other five languages
//  are in Localizable.xcstrings.
//

import Foundation

extension BlessingID {
    var displayName: String {
        switch self {
        case .add: return String(localized: "加碼")
        case .snow: return String(localized: "滾雪球")
        case .cool: return String(localized: "穩手")
        case .gamb: return String(localized: "賭徒")
        case .hot: return String(localized: "連勝體質")
        case .grit: return String(localized: "不屈")
        case .hand: return String(localized: "多一手")
        case .eye: return String(localized: "千里眼")
        case .bank: return String(localized: "利息")
        case .defuse: return String(localized: "拆彈")
        }
    }

    var displayDescription: String {
        switch self {
        case .add: return String(localized: "加分牌的分數 +25%，可以重複買")
        case .snow: return String(localized: "倍數牌的倍率 +0.5，可以重複買")
        case .cool: return String(localized: "危險 1 格的牌絕對不會爆")
        case .gamb: return String(localized: "危險 4 格的牌獎勵變 1.5 倍")
        case .hot: return String(localized: "連中加成上限從 2 倍提高到 3 倍（連中 8 次）")
        case .grit: return String(localized: "爆炸時連中減半（無條件進位），不會歸零")
        case .hand: return String(localized: "每關多 1 手，可以重複買")
        case .eye: return String(localized: "每關開始時送 1 個透視")
        case .bank: return String(localized: "過關時每持有 $5 多拿 $1，最多 $3")
        case .defuse: return String(localized: "每關第一次爆炸無效")
        }
    }

    /// Playstyle hint shown in the shop.
    var displayTag: String {
        switch self {
        case .add, .hand: return String(localized: "任何打法")
        case .snow, .gamb, .defuse: return String(localized: "高危險大倍數")
        case .cool, .hot, .grit: return String(localized: "安全連中")
        case .eye: return String(localized: "魔王關")
        case .bank: return String(localized: "越早買越好")
        }
    }
}

extension BossID {
    var displayName: String {
        switch self {
        case .fog: return String(localized: "濃霧")
        case .crush: return String(localized: "重壓")
        case .short: return String(localized: "急迫")
        case .shaky: return String(localized: "不穩")
        }
    }

    var displayDescription: String {
        switch self {
        case .fog: return String(localized: "其中一張牌完全蓋住，翻開才知道分數和危險度")
        case .crush: return String(localized: "爆炸時，這關目前的分數砍半（前面各關不受影響）")
        case .short: return String(localized: "這關少 2 手")
        case .shaky: return String(localized: "每張牌爆炸率 +10%")
        }
    }
}

extension ModID {
    var displayName: String {
        switch self {
        case .heat: return String(localized: "加溫")
        case .calm: return String(localized: "平靜")
        case .wild: return String(localized: "狂野")
        case .lean: return String(localized: "精簡")
        case .rich: return String(localized: "豐收")
        case .small: return String(localized: "穩賺")
        case .fuse: return String(localized: "短引信")
        case .gold: return String(localized: "淘金")
        }
    }

    var displayDescription: String {
        switch self {
        case .heat: return String(localized: "連中加成翻倍：每連中一次得分 +50%（上限不變）")
        case .calm: return String(localized: "不會出現危險 4 格的牌")
        case .wild: return String(localized: "倍數牌的出現率加倍")
        case .lean: return String(localized: "少 1 手，但過關基本獎勵 +$3")
        case .rich: return String(localized: "剩下的每一手換 $2")
        case .small: return String(localized: "危險 1 格的牌分數 ×2")
        case .fuse: return String(localized: "每張牌爆炸率 +8%，加分牌分數 ×1.4")
        case .gold: return String(localized: "每選中一張牌 +$1")
        }
    }
}

extension ItemID {
    var displayName: String {
        switch self {
        case .peek: return String(localized: "透視")
        case .roll: return String(localized: "重抽")
        case .dbl: return String(localized: "雙倍")
        case .shield: return String(localized: "保命符")
        }
    }
}

extension Rules {
    /// 入門 / 進階 / 老手 / 專家 / 大師 / 傳說 (`lv` 0...5).
    static func difficultyName(_ lv: Int) -> String {
        switch lv {
        case 0: return String(localized: "入門")
        case 1: return String(localized: "進階")
        case 2: return String(localized: "老手")
        case 3: return String(localized: "專家")
        case 4: return String(localized: "大師")
        default: return String(localized: "傳說")
        }
    }

    /// What the level adds on top of the one before it.
    static func difficultyDescription(_ lv: Int) -> String {
        switch lv {
        case 0: return String(localized: "標準規則")
        case 1: return String(localized: "目標分數 ×1.15")
        case 2: return String(localized: "每關少 1 手")
        case 3: return String(localized: "開局沒有保命符和道具")
        case 4: return String(localized: "每張牌爆炸率 +5%")
        default: return String(localized: "商店貴 $1，過關基本獎勵只剩 $2")
        }
    }
}
