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
    @AppStorage("dailyAttempts") var dailyAttempts = 0
    @State private var showAlert = false

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
                    Text("運氣評分：\(LuckLevel.level(for: game.luckScore)) (\(game.luckScore))")
                        .padding()

                    Button("重新開始") {
                        if dailyAttempts < 10 {
                            game.resetGame()
                            dailyAttempts += 1
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
        }
        .alert("今天遊玩次數已達上限！", isPresented: $showAlert) {
            Button("好") { }
        }
        .padding()
        .onAppear {
            AudioManager.shared.playSound("start")
        }
    }
}
