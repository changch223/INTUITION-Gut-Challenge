//
//  LuckLevelStandardsView.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import SwiftUI

struct LuckLevelRange: Identifiable {
    let id = UUID()
    let label: String
    let rangeDescription: String
}

struct LuckLevelStandardsView: View {
    // 固定區間設定
    let levels: [LuckLevelRange] = [
        LuckLevelRange(label: "運氣爆炸差", rangeDescription: "composite < -1.0"),
        LuckLevelRange(label: "運氣極差", rangeDescription: "[-1.0, -0.5)"),
        LuckLevelRange(label: "倒楣透頂", rangeDescription: "[-0.5, 0)"),
        LuckLevelRange(label: "運氣不佳", rangeDescription: "[0, 1)"),
        LuckLevelRange(label: "運氣稍差", rangeDescription: "[1, 2)"),
        LuckLevelRange(label: "普通水準", rangeDescription: "[2, 3)"),
        LuckLevelRange(label: "運氣尚可", rangeDescription: "[3, 4)"),
        LuckLevelRange(label: "小吉", rangeDescription: "[4, 5)"),
        LuckLevelRange(label: "中吉", rangeDescription: "[5, 6)"),
        LuckLevelRange(label: "大吉", rangeDescription: "[6, 7)"),
        LuckLevelRange(label: "運氣極好", rangeDescription: "[7, 8)"),
        LuckLevelRange(label: "超級好運", rangeDescription: "[8, 9)"),
        LuckLevelRange(label: "歐皇現世", rangeDescription: "[9, 10)"),
        LuckLevelRange(label: "運氣之神降臨", rangeDescription: "[10, 11)"),
        LuckLevelRange(label: "運氣之神降臨ProMax", rangeDescription: "≥ 11")
    ]
    
    var body: some View {
        NavigationView {
            List(levels) { level in
                HStack {
                    Text(level.label)
                        .fontWeight(.bold)
                    Spacer()
                    Text(level.rangeDescription)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("運氣評分標準")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        // 使用環境 dismiss 來關閉此頁面
                        // (此 view 可用 .sheet 呈現)
                        dismiss()
                    }
                }
            }
        }
    }
    
    @Environment(\.dismiss) var dismiss
}
