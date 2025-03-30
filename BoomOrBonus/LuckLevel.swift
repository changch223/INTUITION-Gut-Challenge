import Foundation

struct LuckLevel {
    /// 根據最終數值 (currentValue) 回傳對應的運氣評語
    static func level(currentValue: Int) -> String {
        let score = Double(currentValue)
        if score < -50 {
            return "運氣爆炸差"
        } else if score < -10 {
            return "運氣極差"
        } else if score < 0 {
            return "倒楣透頂"
        } else if score < 3 {
            return "運氣不佳"
        } else if score < 5 {
            return "運氣稍差"
        } else if score < 10 {
            return "普通水準"
        } else if score < 15 {
            return "運氣尚可"
        } else if score < 30 {
            return "小吉"
        } else if score < 50 {
            return "中吉"
        } else if score < 100 {
            return "大吉"
        } else if score < 500 {
            return "運氣極好"
        } else if score < 1000 {
            return "超級好運"
        } else if score < 5000 {
            return "歐皇現世"
        } else if score < 10000 {
            return "運氣之神降臨"
        } else {
            return "運氣之神降臨ProMax"
        }
    }
}
