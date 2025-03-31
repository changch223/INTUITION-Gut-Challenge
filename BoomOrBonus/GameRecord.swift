//
//  Untitled.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import Foundation

struct GameRecord: Identifiable, Codable {
    let id: UUID
    let date: String     // 格式：yyyy-MM-dd
    let score: Int       // 安全選項數（得分）
    let finalValue: Int  // 遊戲結束時的最終數值
    let levelsPassed: Int
    let luckLevel: String
}

class GameRecordManager: ObservableObject {
    @Published var records: [GameRecord] = []
    private let recordKey = "gameRecords"
    
    init() {
        loadRecords()
    }
    
    func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: recordKey),
           let savedRecords = try? JSONDecoder().decode([GameRecord].self, from: data) {
            self.records = savedRecords
        }
    }
    
    /// 新增或更新紀錄：若同一天已有紀錄則只保留得分較高的那筆
    func addOrUpdateRecord(record: GameRecord) {
        if let index = records.firstIndex(where: { $0.date == record.date }) {
            let existing = records[index]
            
            if record.finalValue > existing.finalValue ||
               (record.finalValue == existing.finalValue && record.levelsPassed > existing.levelsPassed) {
                records[index] = record
            }
        } else {
            records.append(record)
        }
        saveRecords()
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: recordKey)
        }
    }
}

