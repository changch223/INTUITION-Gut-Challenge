import Foundation

struct IntuitionLevel {
    /// 根據最終數值 (currentValue) 回傳對應的直覺評語
    static func level(currentValue: Int) -> String {
        let score = Double(currentValue)
        if score < -50 {
            return NSLocalizedString("IntuitionLevel_VeryBad", comment: "直覺評分：直覺爆炸差")
        } else if score < -10 {
            return NSLocalizedString("IntuitionLevel_ExtremelyBad", comment: "直覺評分：直覺極差")
        } else if score < 0 {
            return NSLocalizedString("IntuitionLevel_Terrible", comment: "直覺評分：倒楣透頂")
        } else if score < 3 {
            return NSLocalizedString("IntuitionLevel_Bad", comment: "直覺評分：直覺不佳")
        } else if score < 5 {
            return NSLocalizedString("IntuitionLevel_SlightlyBad", comment: "直覺評分：直覺稍差")
        } else if score < 10 {
            return NSLocalizedString("IntuitionLevel_Average", comment: "直覺評分：普通水準")
        } else if score < 15 {
            return NSLocalizedString("IntuitionLevel_Fair", comment: "直覺評分：直覺尚可")
        } else if score < 30 {
            return NSLocalizedString("IntuitionLevel_SmallBlessing", comment: "直覺評分：小吉")
        } else if score < 50 {
            return NSLocalizedString("IntuitionLevel_MediumBlessing", comment: "直覺評分：中吉")
        } else if score < 100 {
            return NSLocalizedString("IntuitionLevel_BigBlessing", comment: "直覺評分：大吉")
        } else if score < 500 {
            return NSLocalizedString("IntuitionLevel_VeryGood", comment: "直覺評分：直覺極好")
        } else if score < 1000 {
            return NSLocalizedString("IntuitionLevel_SuperGood", comment: "直覺評分：超級好運")
        } else if score < 5000 {
            return NSLocalizedString("IntuitionLevel_Legendary", comment: "直覺評分：歐皇現世")
        } else if score < 10000 {
            return NSLocalizedString("IntuitionLevel_God", comment: "直覺評分：直覺之神降臨")
        } else {
            return NSLocalizedString("IntuitionLevel_GodProMax", comment: "直覺評分：直覺之神降臨ProMax")
        }
    }
}

