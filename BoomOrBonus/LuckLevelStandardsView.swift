import SwiftUI

struct LuckLevelRange: Identifiable {
    let id = UUID()
    let label: String
    let rangeDescription: String
}

struct LuckLevelStandardsView: View {
    // 依據最終分數定義評分標準，直觀顯示門檻
    let levels: [LuckLevelRange] = [
        LuckLevelRange(label: "運氣爆炸差", rangeDescription: "final score < -50"),
        LuckLevelRange(label: "運氣極差", rangeDescription: "-50 ~ -10"),
        LuckLevelRange(label: "倒楣透頂", rangeDescription: "-10 ~ 0"),
        LuckLevelRange(label: "運氣不佳", rangeDescription: "0 ~ 3"),
        LuckLevelRange(label: "運氣稍差", rangeDescription: "3 ~ 5"),
        LuckLevelRange(label: "普通水準", rangeDescription: "5 ~ 10"),
        LuckLevelRange(label: "運氣尚可", rangeDescription: "10 ~ 15"),
        LuckLevelRange(label: "小吉", rangeDescription: "15 ~ 30"),
        LuckLevelRange(label: "中吉", rangeDescription: "30 ~ 50"),
        LuckLevelRange(label: "大吉", rangeDescription: "50 ~ 100"),
        LuckLevelRange(label: "運氣極好", rangeDescription: "100 ~ 500"),
        LuckLevelRange(label: "超級好運", rangeDescription: "500 ~ 1000"),
        LuckLevelRange(label: "歐皇現世", rangeDescription: "1000 ~ 5000"),
        LuckLevelRange(label: "運氣之神降臨", rangeDescription: "5000 ~ 10000"),
        LuckLevelRange(label: "運氣之神降臨ProMax", rangeDescription: "final score ≥ 10000")
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
                        dismiss()
                    }
                }
            }
        }
    }
    
    @Environment(\.dismiss) var dismiss
}
