//
//  Untitled.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import Foundation

struct LuckLevel {
    static let labels: [String] = [
        "運氣爆炸差",       //（負值區間：composite < -1.0）
        "運氣極差",         //（-1.0 ≤ composite < -0.5）
        "倒楣透頂",         //（-0.5 ≤ composite < 0）
        "運氣不佳",         // composite in [0,1)
        "運氣稍差",         // [1,2)
        "普通水準",         // [2,3)
        "運氣尚可",         // [3,4)
        "小吉",             // [4,5)
        "中吉",             // [5,6)
        "大吉",             // [6,7)
        "運氣極好",         // [7,8)
        "超級好運",         // [8,9)
        "歐皇現世",         // [9,10)
        "運氣之神降臨",     // [10,11)
        "運氣之神降臨ProMax" // composite ≥ 11
    ]
    
    /// 根據安全選項數 (safeScore) 與最終數值 (currentValue) 計算 composite 分數，
    /// 計算公式：composite = safeScore + log10(currentValue + 1)
    /// 並依據分數回傳對應的運氣評語
    static func level(safeScore: Int, currentValue: Int) -> String {
        let composite = Double(safeScore) + log10(Double(currentValue + 1))
        
        if composite < 0 {
            if composite < -1.0 {
                return labels[0]  // "運氣爆炸差"
            } else if composite < -0.5 {
                return labels[1]  // "運氣極差"
            } else {
                return labels[2]  // "倒楣透頂"
            }
        } else {
            // 當 composite 為正時，0~1 區間對應 index 3 ("運氣不佳")
            let index = min(Int(composite) + 3, labels.count - 1)
            return labels[index]
        }
    }
}
