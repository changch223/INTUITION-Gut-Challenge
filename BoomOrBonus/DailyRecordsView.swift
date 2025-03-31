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
                        Text("\(NSLocalizedString("Date", comment: "日期前綴")) \(record.date)")
                            .font(.headline)
                        Text("\(NSLocalizedString("FinalValueRecord", comment: "最終數值前綴")) \(record.finalValue)")
                        Text("\(NSLocalizedString("LevelsPassedRecord", comment: "闖關數前綴")) \(record.levelsPassed)")
                        Text("\(NSLocalizedString("LuckRating", comment: "運氣評分前綴")) \(record.luckLevel)")
                    }
                    .padding(5)
                }
            }
            .navigationTitle(NSLocalizedString("DailyRecordsTitle", comment: "每日最高紀錄標題"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Close", comment: "關閉按鈕")) {
                        dismiss()
                    }
                }
            }
        }
    }
}


