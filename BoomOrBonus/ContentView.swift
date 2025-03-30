//
//  ContentView.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//


import SwiftData
import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameLogic()
    @StateObject private var recordManager = GameRecordManager()
    
    // 原本的已使用次數
    @AppStorage("dailyAttempts") var dailyAttempts = 0
    
    // 用於記錄上次重置日期
    @AppStorage("lastResetDate") var lastResetDate: String = ""
    
    // **把 maxAttempts 也改用 @AppStorage **
    @AppStorage("maxAttempts") var maxAttempts = 5
    
    @State private var showAlert = false
    @State private var showProbabilities = false
    @State private var showRecords = false
    @State private var showLuckLevelStandards = false
    
    @State private var hasRecordedResult = false

    var body: some View {
        ZStack {
            // 背景漸層
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.2)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer() // 讓內容更偏向畫面中間
                
                // 遊戲標題
                Text("GameTitle")
                    .font(.largeTitle)
                    .bold()
                
                // 剩餘遊戲次數顯示
                Text("\(NSLocalizedString("RemainingAttempts", comment: "剩餘遊戲次數前綴")) \(maxAttempts - dailyAttempts)")
                    .font(.headline)
                    .padding(.bottom, 10)

                // 當前數值
                Text("\(NSLocalizedString("CurrentValue", comment: "當前數值前綴")) \(game.currentValue)")
                    .font(.title)
                    .padding(.horizontal)

                // 闖關數
                Text("\(NSLocalizedString("LevelsPassedPrefix", comment: "前綴文字：例如『你已闖了』")) \(game.levelsPassed) \(NSLocalizedString("LevelsPassedSuffix", comment: "後綴文字：例如『關』"))")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)

                if !game.isGameOver {
                    // 選項按鈕
                    HStack(spacing: 40) {
                        ForEach(game.options.indices, id: \.self) { index in
                            Button(action: {
                                withAnimation(.spring) {
                                    game.selectOption(game.options[index])
                                    AudioManager.shared.playSound(
                                        game.options[index].isBomb ? "bomb" : "success"
                                    )
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.blue)
                                        .frame(width: 120, height: 120)
                                        .shadow(radius: 5)
                                    
                                    HStack(spacing: 8) {
                                        Text(game.options[index].operation.rawValue)
                                        Text("\(game.options[index].number)")
                                    }
                                    .font(.title2)
                                    .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                
                } else {
                    // 遊戲結束畫面
                    VStack(spacing: 15) {
                        Text(NSLocalizedString("GameOver", comment: "遊戲結束標題"))
                                .font(.title)
                                .bold()
                        
                        Text("\(NSLocalizedString("FinalValue", comment: "最終數值前綴")) \(game.currentValue)")
                        Text("\(NSLocalizedString("LevelsPassed", comment: "闖關數前綴")) \(game.levelsPassed)")
                            
                        
                        // 注意這裡已移除 safeScore，只用 currentValue
                        Text("\(NSLocalizedString("LuckScore", comment: "運氣評分前綴")) \(LuckLevel.level(currentValue: game.currentValue))")
                                .padding()
                                .font(.headline)
                        
                        Button(NSLocalizedString("Restart", comment: "重新開始按鈕標題")) {
                            // 改為比較 dailyAttempts 與 maxAttempts
                            if dailyAttempts < maxAttempts {
                                game.resetGame()
                                dailyAttempts += 1 // 使用次數 +1
                                hasRecordedResult = false
                            } else {
                                showAlert = true
                            }
                        }
                        .buttonStyle(GameButtonStyle(backgroundColor: .green))
                    }
                }
                
                Spacer()
                
                // 下方功能按鈕
                HStack(spacing: 16) {
                    Button("ProbabilityInfo") {
                        showProbabilities = true
                    }
                    .buttonStyle(GameButtonStyle(backgroundColor: .orange))
                    
                    Button("GameRecords") {
                        showRecords = true
                    }
                    .buttonStyle(GameButtonStyle(backgroundColor: .purple))
                    
                    Button("RatingStandards") {
                        showLuckLevelStandards = true
                    }
                    .buttonStyle(GameButtonStyle(backgroundColor: .gray))
                }
                .padding(.bottom, 10)
                
                // 新增一個按鈕，可一次增加 3 次可用次數
                Button("ExtraAttempts") {
                    maxAttempts += 3
                }
                .buttonStyle(GameButtonStyle(backgroundColor: .pink))
                .padding(.bottom, 30)
            }
        }
        // 達到上限的提示
        .alert("AttemptsLimitReached", isPresented: $showAlert) {
            Button("OK") { }
        }
        .onAppear {
            // 每日重置邏輯
            let currentDateString = Date().formatted(.dateTime.year().month().day())
            if lastResetDate != currentDateString {
                // 重新把已使用次數清零、最大次數恢復初始值
                dailyAttempts = 0
                maxAttempts = 5
                lastResetDate = currentDateString
            }
            AudioManager.shared.playSound("start")
        }
        // 顯示機率資訊
        .sheet(isPresented: $showProbabilities) {
            ProbabilityView()
        }
        // 顯示每日遊玩記錄
        .sheet(isPresented: $showRecords) {
            DailyRecordsView(recordManager: recordManager)
        }
        // 顯示評分標準
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
                    luckLevel: LuckLevel.level(currentValue: game.currentValue)
                )
                recordManager.addOrUpdateRecord(record: record)
                hasRecordedResult = true
            }
        }
    }
}

// 統一按鈕風格
struct GameButtonStyle: ButtonStyle {
    var backgroundColor: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(10)
            .shadow(color: .gray.opacity(0.4), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}




struct ProbabilityView: View {
    @Environment(\.dismiss) var dismiss

    // 固定的演算子機率
    let operatorProbabilities: [(name: String, probability: Double)] = [
        ("Addition", 60),
        ("Subtraction", 10),
        ("Multiplication", 30)
    ]
    
    // 假設此函式已存在於 Option 結構內
    // static func numberProbabilities() -> [(number: Int, probability: Double)]
    let numberProbabilities = Option.numberProbabilities()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(NSLocalizedString("OperatorProbabilitySection", comment: "演算子機率區段"))) {
                    ForEach(operatorProbabilities, id: \.name) { op in
                        HStack {
                            Text(NSLocalizedString(op.name, comment: "運算子名稱"))
                            Spacer()
                            Text("\(String(format: "%.2f", op.probability))%")
                        }
                    }
                }
                Section(header: Text(NSLocalizedString("NumberProbabilitySection", comment: "數字機率區段"))) {
                    ForEach(numberProbabilities, id: \.number) { item in
                        HStack {
                            Text("\(NSLocalizedString("NumberPrefix", comment: "數字前綴")) \(item.number)")
                            Spacer()
                            
                            // 依照不同區間格式化
                            let formattedProbability: String = {
                                if item.probability < 0.01 {
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
            .navigationTitle(NSLocalizedString("ProbabilityInfo", comment: "機率資訊"))
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
