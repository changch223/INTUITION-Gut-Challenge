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

    /// `date` is a locale-formatted string (not sortable as text). GameRecordManager appends each new day and
    /// replaces an existing day in place, so the array is oldest first: reversed it is newest first.
    static func newestFirst(_ records: [GameRecord]) -> [GameRecord] { records.reversed() }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Self.newestFirst(recordManager.records)) { record in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(NSLocalizedString("Date", comment: "日期前綴")) \(record.date)")
                            .font(.headline)
                        Text("\(NSLocalizedString("FinalValueRecord", comment: "最終數值前綴")) \(record.finalValue)")
                        Text("\(NSLocalizedString("LevelsPassedRecord", comment: "闖關數前綴")) \(record.levelsPassed)")
                        Text("\(NSLocalizedString("IntuitionRating", comment: "直覺評分前綴")) \(record.IntuitionLevel)")
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


