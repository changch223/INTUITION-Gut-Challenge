//
//  Untitled.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import Foundation

struct LuckLevel {
    let scoreRange: ClosedRange<Int>
    let title: String

    static let levels: [LuckLevel] = [
        LuckLevel(scoreRange: 0...1, title: "運氣爆炸差"),
        LuckLevel(scoreRange: 2...3, title: "倒楣透頂"),
        LuckLevel(scoreRange: 4...5, title: "運氣不佳"),
        LuckLevel(scoreRange: 6...7, title: "普通水準"),
        LuckLevel(scoreRange: 8...9, title: "小吉"),
        LuckLevel(scoreRange: 10...11, title: "中吉"),
        LuckLevel(scoreRange: 12...13, title: "大吉"),
        LuckLevel(scoreRange: 14...15, title: "超級好運"),
        LuckLevel(scoreRange: 16...17, title: "歐皇現世"),
        LuckLevel(scoreRange: 18...20, title: "運氣之神降臨")
    ]

    static func level(for score: Int) -> String {
        levels.first { $0.scoreRange.contains(score) }?.title ?? "未知"
    }
}
