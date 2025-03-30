//
//  Untitled.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import SwiftUI

struct DailyRecordsView: View {
    @ObservedObject var recordManager: GameRecordManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(recordManager.records) { record in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("日期：\(record.date)")
                            .font(.headline)
                        Text("最終數值：\(record.finalValue)")
                        Text("安全選項數：\(record.score)  闖關：\(record.levelsPassed)")
                        Text("運氣評分：\(record.luckLevel)")
                    }
                    .padding(5)
                }
            }
            .navigationTitle("每日最高紀錄")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }
}


