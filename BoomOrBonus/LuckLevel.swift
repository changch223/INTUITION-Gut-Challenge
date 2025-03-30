import Foundation

struct LuckLevel {
    /// 根據最終數值 (currentValue) 回傳對應的運氣評語
    static func level(currentValue: Int) -> String {
        let score = Double(currentValue)
        if score < -50 {
            return NSLocalizedString("LuckLevel_VeryBad", comment: "運氣評分：運氣爆炸差")
        } else if score < -10 {
            return NSLocalizedString("LuckLevel_ExtremelyBad", comment: "運氣評分：運氣極差")
        } else if score < 0 {
            return NSLocalizedString("LuckLevel_Terrible", comment: "運氣評分：倒楣透頂")
        } else if score < 3 {
            return NSLocalizedString("LuckLevel_Bad", comment: "運氣評分：運氣不佳")
        } else if score < 5 {
            return NSLocalizedString("LuckLevel_SlightlyBad", comment: "運氣評分：運氣稍差")
        } else if score < 10 {
            return NSLocalizedString("LuckLevel_Average", comment: "運氣評分：普通水準")
        } else if score < 15 {
            return NSLocalizedString("LuckLevel_Fair", comment: "運氣評分：運氣尚可")
        } else if score < 30 {
            return NSLocalizedString("LuckLevel_SmallBlessing", comment: "運氣評分：小吉")
        } else if score < 50 {
            return NSLocalizedString("LuckLevel_MediumBlessing", comment: "運氣評分：中吉")
        } else if score < 100 {
            return NSLocalizedString("LuckLevel_BigBlessing", comment: "運氣評分：大吉")
        } else if score < 500 {
            return NSLocalizedString("LuckLevel_VeryGood", comment: "運氣評分：運氣極好")
        } else if score < 1000 {
            return NSLocalizedString("LuckLevel_SuperGood", comment: "運氣評分：超級好運")
        } else if score < 5000 {
            return NSLocalizedString("LuckLevel_Legendary", comment: "運氣評分：歐皇現世")
        } else if score < 10000 {
            return NSLocalizedString("LuckLevel_God", comment: "運氣評分：運氣之神降臨")
        } else {
            return NSLocalizedString("LuckLevel_GodProMax", comment: "運氣評分：運氣之神降臨ProMax")
        }
    }
}

