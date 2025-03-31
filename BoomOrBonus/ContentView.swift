import SwiftData
import SwiftUI

struct IconTransparent: View {
    var body: some View {
        // 這裡採用 system image "star.fill" 作為示範圖示
        Image("IconTransparent")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(.blue)
            .opacity(0.7) // 設定透明度
    }
}

struct ContentView: View {
    
    @StateObject private var game = GameLogic()
    @StateObject private var recordManager = GameRecordManager()
    
    @AppStorage("dailyAttempts") var dailyAttempts = 0
    @AppStorage("lastResetDate") var lastResetDate: String = ""
    @AppStorage("maxAttempts") var maxAttempts = 5
    
    @State private var showAlert = false
    @State private var showProbabilities = false
    @State private var showRecords = false
    @State private var showLuckLevelStandards = false
    @State private var hasRecordedResult = false
    
    @State private var encouragementMessage: String = ""
    @State private var showEncouragement: Bool = false
    
    // 14 個鼓勵訊息的 key
    let encouragementKeys = [
        "Encouragement1",
        "Encouragement2",
        "Encouragement3",
        "Encouragement4",
        "Encouragement5",
        "Encouragement6",
        "Encouragement7",
        "Encouragement8",
        "Encouragement9",
        "Encouragement10",
        "Encouragement11",
        "Encouragement12",
        "Encouragement13",
        "Encouragement14",
    ]
    
    var body: some View {
        // 取得螢幕寬度，依據裝置大小調整字體
        let screenWidth = UIScreen.main.bounds.width
        let isSmallDevice = screenWidth < 375 // iPhone SE 或 iPhone 13 mini
        
        ZStack {
            // 背景漸層
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.2)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 新增上方 Header，包含 IconTransparent 與 Google AdMob Banner
                VStack(spacing: 10) {
                    // 假設 IconTransparent 是一個自定義 View
                    IconTransparent()
                        .frame(width: 100, height: 100)
                    
                    // 假設 GoogleAdBanner 是你封裝好的 Google AdMob Banner 視圖
                    //GoogleAdBanner()
                    //    .frame(height: 50)
                }.padding(.top, 20)
                
                
                // 遊戲標題
                Text("GameTitle")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                     
                
                // 遊戲說明
                Text(NSLocalizedString("GameDescription", comment: "遊戲說明"))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .fixedSize(horizontal: false, vertical: true) // 允許多行換行
                    .minimumScaleFactor(0.6)
                                
                // 當前數值
                Text("\(NSLocalizedString("CurrentValue", comment: "當前數值前綴")) \(game.currentValue)")
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                // 闖關數
                Text("\(NSLocalizedString("LevelsPassedPrefix", comment: "前綴文字：例如『你已闖了』")) \(game.levelsPassed) \(NSLocalizedString("LevelsPassedSuffix", comment: "後綴文字：例如『關』"))")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                
                if !game.isGameOver {
                    // 選項按鈕
                    HStack(spacing: 40) {
                        ForEach(game.options.indices, id: \.self) { index in
                            Button(action: {
                                withAnimation(.spring) {
                                    let selectedOption = game.options[index]
                                    game.selectOption(selectedOption)
                                    
                                    // 延遲 0.1 秒後播放聲音及觸覺回饋，讓動畫同步
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if selectedOption.isBomb {
                                            AudioManager.shared.playSound("ButtonFail")
                                            HapticManager.shared.playError()
                                        } else {
                                            AudioManager.shared.playSound("ButtonSuccess")
                                            HapticManager.shared.playSuccess()
                                            let randomKey = encouragementKeys.randomElement()!
                                            encouragementMessage = NSLocalizedString(randomKey, comment: "")
                                            showEncouragement = true
                                            
                                            // 0.5 秒後隱藏鼓勵訊息
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                withAnimation {
                                                    showEncouragement = false
                                                }
                                            }
                                        }
                                    }
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
                    // 遊戲結束畫面：調整後的結果展示
                    VStack(spacing: 20) {
                        Text(NSLocalizedString("GameOver", comment: "遊戲結束標題"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        // 分數卡片：突顯最終數值、闖關數與運氣評分
                        VStack(spacing: 15) {
                            Text("\(NSLocalizedString("FinalValue", comment: "最終數值前綴")) \(game.currentValue)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("\(NSLocalizedString("LevelsPassed", comment: "闖關數前綴")) \(game.levelsPassed)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("\(NSLocalizedString("LuckScore", comment: "運氣評分前綴")) \(LuckLevel.level(currentValue: game.currentValue))")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.4), radius: 8, x: 0, y: 4)
                        
                        Button(NSLocalizedString("Restart", comment: "重新開始按鈕標題")) {
                            AudioManager.shared.playSound("Click")
                            HapticManager.shared.playClick()
                            
                            if dailyAttempts < maxAttempts {
                                game.resetGame()
                                dailyAttempts += 1
                                hasRecordedResult = false
                            } else {
                                showAlert = true
                            }
                        }
                        .buttonStyle(GameButtonStyle(backgroundColor: .green))
                    }
                    .padding(.horizontal)
                }
                
                // 加入鼓勵訊息視圖
                if showEncouragement {
                    Text(encouragementMessage)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(100)
                        .transition(.scale)
                        .zIndex(1) // 確保在最上層
                }
                
                Spacer()
                
                // 下方功能按鈕
                HStack(spacing: 16) {
                    Button("ProbabilityInfo") {
                        AudioManager.shared.playSound("Click")
                        HapticManager.shared.playClick()
                        showProbabilities = true
                    }
                    .buttonStyle(GameButtonStyle(backgroundColor: .orange))
                    
                    Button("GameRecords") {
                        AudioManager.shared.playSound("Click")
                        HapticManager.shared.playClick()
                        showRecords = true
                    }
                    .buttonStyle(GameButtonStyle(backgroundColor: .purple))
                    
                    Button("RatingStandards") {
                        AudioManager.shared.playSound("Click")
                        HapticManager.shared.playClick()
                        showLuckLevelStandards = true
                    }
                    .buttonStyle(GameButtonStyle(backgroundColor: .gray))
                }
                
                
                
                // 新增一個按鈕，可一次增加 3 次可用次數
                Button("ExtraAttempts") {
                    AudioManager.shared.playSound("Click")
                    HapticManager.shared.playClick()
                    if let rootVC = UIApplication.rootViewController {
                            RewardedAdManager.shared.showAd(from: rootVC) {
                                maxAttempts += 3
                            }
                    } else {
                        print("❗找不到 rootViewController")
                    }
                }
                .buttonStyle(GameButtonStyle(backgroundColor: .pink))
                
                // 剩餘遊戲次數顯示
                Text("\(NSLocalizedString("RemainingAttempts", comment: "剩餘遊戲次數前綴")) \(maxAttempts - dailyAttempts)")
                    .font(.headline)
                    .padding(.bottom, 10)
                
                BannerAdView(adUnitID: "ca-app-pub-9275380963550837/2702683361")
                    .frame(height: 50)
                
            }
        }
        .alert("AttemptsLimitReached", isPresented: $showAlert) {
            Button("OK") { }
        }
        .onAppear {
            let currentDateString = Date().formatted(.dateTime.year().month().day())
                if lastResetDate != currentDateString {
                    dailyAttempts = 0
                    maxAttempts = 5
                    lastResetDate = currentDateString
                }
                AudioManager.shared.playSound("start")

                // ✅ 提前載入 Reward 廣告
                RewardedAdManager.shared.loadRewardedAd()
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

    let operatorProbabilities: [(name: String, probability: Double)] = [
        ("Addition", 60),
        ("Subtraction", 10),
        ("Multiplication", 30)
    ]
    
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
