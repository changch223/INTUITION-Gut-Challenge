//
//  Untitled.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import Foundation

struct LuckLevel {
    static let labels: [String] = [
        // 負分區間
        "運氣爆炸差",    // composite < -1.0
        "運氣極差",      // -1.0 ≤ composite < -0.5
        "倒楣透頂",      // -0.5 ≤ composite < 0

        // 正分區間
        "運氣不佳",      // [0,1)
        "運氣稍差",      // [1,2)
        "普通水準",      // [2,3)
        "運氣尚可",      // [3,4)
        "小吉",         // [4,5)
        "中吉",         // [5,6)
        "大吉",         // [6,7)
        "運氣極好",      // [7,8)
        "超級好運",      // [8,9)
        "歐皇現世",      // [9,10)
        "運氣之神降臨",   // [10,11)
        "運氣之神降臨ProMax" // ≥ 11
    ]
    
    /// 根據安全選項數 (safeScore) 與最終數值 (currentValue) 計算綜合分數，
    /// composite = safeScore + log10(adjustedValue)
    /// - 其中 adjustedValue = max(1, currentValue + 1)，避免 log10(<=0)
    static func level(safeScore: Int, currentValue: Int) -> String {
        // 防止 log10(0) 或 log10(負數) 出現 NaN / -∞
        let adjustedValue = max(1, currentValue + 1)
        let composite = Double(safeScore) + log10(Double(adjustedValue))
        
        // 若 composite < 0，依區間決定
        if composite < 0 {
            if composite < -1.0 {
                return labels[0]  // 運氣爆炸差
            } else if composite < -0.5 {
                return labels[1]  // 運氣極差
            } else {
                return labels[2]  // 倒楣透頂
            }
        } else {
            // composite >= 0 時，0~1 對應 index = 3 ("運氣不佳")
            // 1~2 對應 index = 4 ("運氣稍差")，依此類推
            let index = min(Int(composite) + 3, labels.count - 1)
            return labels[index]
        }
    }
}
