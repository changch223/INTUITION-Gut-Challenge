//
//  ContentView.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import SwiftUI
import SwiftData

import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameLogic()
    @StateObject private var recordManager = GameRecordManager()
    
    @AppStorage("dailyAttempts") var dailyAttempts = 0
    
    @State private var showAlert = false
    @State private var showProbabilities = false
    @State private var showRecords = false
    @State private var showLuckLevelStandards = false
    
    @State private var hasRecordedResult = false

    var body: some View {
        VStack(spacing: 30) {
            Text("運氣測試遊戲")
                .font(.largeTitle).bold()
                .padding(.top, 40)

            // 顯示當前數值
            Text("當前數值：\(game.currentValue)")
                .font(.title)

            // 顯示闖了幾關
            Text("你已闖了 \(game.levelsPassed) 關")
                .font(.title3)
                .foregroundColor(.gray)

            if !game.isGameOver {
                // 安全選項 / 炸彈選項按鈕
                HStack(spacing: 40) {
                    ForEach(game.options.indices, id: \.self) { index in
                        Button(action: {
                            withAnimation(.spring) {
                                game.selectOption(game.options[index])
                                AudioManager.shared.playSound(game.options[index].isBomb ? "bomb" : "success")
                            }
                        }) {
                            VStack {
                                Text("\(game.options[index].operation.rawValue) \(game.options[index].number)")
                                    .font(.title)
                                    .frame(width: 120, height: 120)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(15)
                                    .shadow(radius: 5)
                            }
                        }
                    }
                }
            } else {
                // 遊戲結束畫面
                VStack {
                    Text("遊戲結束！")
                        .font(.title).bold()
                    
                    Text("最終數值：\(game.currentValue)")
                    Text("安全選項數：\(game.luckScore)")
                    Text("闖關數：\(game.levelsPassed)")
                    Text("運氣評分：\(LuckLevel.level(safeScore: game.luckScore, currentValue: game.currentValue))")
                        .padding()
                    
                    Button("重新開始") {
                        if dailyAttempts < 2 {
                            game.resetGame()
                            dailyAttempts += 1
                            hasRecordedResult = false
                        } else {
                            showAlert = true
                        }
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            // 下方功能按鈕
            HStack(spacing: 20) {
                Button("顯示機率資訊") {
                    showProbabilities = true
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("每日遊玩記錄") {
                    showRecords = true
                }
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                // 顯示評分標準
                Button("評分標準") {
                    showLuckLevelStandards = true
                }
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .alert("今天遊玩次數已達上限！", isPresented: $showAlert) {
            Button("好") { }
        }
        .padding(.bottom, 30)
        .onAppear {
            AudioManager.shared.playSound("start")
        }
        .sheet(isPresented: $showProbabilities) {
            ProbabilityView()
        }
        .sheet(isPresented: $showRecords) {
            DailyRecordsView(recordManager: recordManager)
        }
        .sheet(isPresented: $showLuckLevelStandards) {
            LuckLevelStandardsView()
        }
        // 遊戲結束後記錄該局結果（只記一次）
        .onChange(of: game.isGameOver) { newValue in
            if newValue && !hasRecordedResult {
                let dateString = Date().formatted(.dateTime.year().month().day())
                let record = GameRecord(
                    id: UUID(),
                    date: dateString,
                    score: game.luckScore,
                    finalValue: game.currentValue,
                    levelsPassed: game.levelsPassed,
                    luckLevel: LuckLevel.level(safeScore: game.luckScore, currentValue: game.currentValue)
                )
                recordManager.addOrUpdateRecord(record: record)
                hasRecordedResult = true
            }
        }
    }
}



struct ProbabilityView: View {
    @Environment(\.dismiss) var dismiss

    // 固定的演算子機率
    let operatorProbabilities: [(name: String, probability: Double)] = [
        ("加法 (+)", 60),
        ("減法 (-)", 20),
        ("乘法 (×)", 20)
    ]
    
    // 假設此函式已存在於 Option 結構內
    // static func numberProbabilities() -> [(number: Int, probability: Double)]
    let numberProbabilities = Option.numberProbabilities()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("演算子機率")) {
                    ForEach(operatorProbabilities, id: \.name) { op in
                        HStack {
                            Text(op.name)
                            Spacer()
                            Text("\(String(format: "%.2f", op.probability))%")
                        }
                    }
                }
                Section(header: Text("數字機率 (1 - 50)")) {
                    ForEach(numberProbabilities, id: \.number) { item in
                        HStack {
                            Text("數字 \(item.number)")
                            Spacer()
                            
                            // 依照不同區間格式化
                            let formattedProbability: String = {
                                if item.probability < 0.01 {
                                    // 小於 0.01 時，顯示 8 位小數
                                    // e.g. 0.00001234
                                    return String(format: "%.5f", item.probability)
                                } else {
                                    return String(format: "%.2f", item.probability)
                                }
                            }()
                            
                            
                            Text("\(formattedProbability)%")
                            
                        }
                    }
                }
            }
            .navigationTitle("機率資訊")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}
