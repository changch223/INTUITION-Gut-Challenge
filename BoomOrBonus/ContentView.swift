//
//  ContentView.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var game = GameLogic()
    @StateObject private var recordManager = GameRecordManager()
    @AppStorage("dailyAttempts") var dailyAttempts = 0
    @State private var showAlert = false
    @State private var showProbabilities = false
    @State private var showRecords = false
    @State private var hasRecordedResult = false

    var body: some View {
        VStack(spacing: 40) {
            Text("運氣測試遊戲")
                .font(.largeTitle).bold()
                .padding()

            Text("當前數值：\(game.currentValue)")
                .font(.title)
            
            if !game.isGameOver {
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
                VStack {
                    Text("遊戲結束！")
                        .font(.title).bold()
                    
                    Text("最終數值：\(game.currentValue)")
                    Text("安全選項數：\(game.luckScore)")
                    Text("闖關數：\(game.levelsPassed)")
                    Text("運氣評分：\(LuckLevel.level(safeScore: game.luckScore, currentValue: game.currentValue))")
                        .padding()
                    
                    Button("重新開始") {
                        if dailyAttempts < 5 {
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
        }
        .alert("今天遊玩次數已達上限！", isPresented: $showAlert) {
            Button("好") { }
        }
        .padding()
        .onAppear {
            AudioManager.shared.playSound("start")
        }
        .sheet(isPresented: $showProbabilities) {
            ProbabilityView()
        }
        .sheet(isPresented: $showRecords) {
            DailyRecordsView(recordManager: recordManager)
        }
        // 當遊戲結束時根據最新數據更新當日最高紀錄（只記錄一次）
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

    let operatorProbabilities: [(name: String, probability: Double)] = [
        ("加法 (+)", 60),
        ("減法 (-)", 20),
        ("乘法 (×)", 20)
    ]
    
    let numberProbabilities = Option.numberProbabilities()  // 假設此函式已存在，回傳 [(number: Int, probability: Double)]
    
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
                            let formattedProbability: String = {
                                if item.probability < 0.01 {
                                    return String(format: "%.2e", item.probability)
                                } else {
                                    return String(format: "%.2f", item.probability)
                                }
                            }()
                            if item.number >= 40 {
                                Text("\(formattedProbability)%")
                                    .font(.system(size: 10))
                                    .minimumScaleFactor(0.5)
                            } else {
                                Text("\(formattedProbability)%")
                            }
                        }
                    }
                }
            }
            .navigationTitle("機率資訊")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }
}
