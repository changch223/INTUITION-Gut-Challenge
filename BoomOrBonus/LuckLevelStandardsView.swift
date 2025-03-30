import SwiftUI

struct LuckLevelRange: Identifiable {
    let id = UUID()
    let label: String
    let rangeDescription: String
}

struct LuckLevelStandardsView: View {
   
    // 依據最終分數定義評分標準，直觀顯示門檻
    let levels: [LuckLevelRange] = [
        LuckLevelRange(label: NSLocalizedString("LuckLevel_VeryBad", comment: "運氣評分：運氣爆炸差"), rangeDescription: NSLocalizedString("Range_VeryBad", comment: "最終分數描述：final score < -50")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_ExtremelyBad", comment: "運氣評分：運氣極差"), rangeDescription: NSLocalizedString("Range_ExtremelyBad", comment: "最終分數描述：-50 ~ -10")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_Terrible", comment: "運氣評分：倒楣透頂"), rangeDescription: NSLocalizedString("Range_Terrible", comment: "最終分數描述：-10 ~ 0")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_Bad", comment: "運氣評分：運氣不佳"), rangeDescription: NSLocalizedString("Range_Bad", comment: "最終分數描述：0 ~ 3")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_SlightlyBad", comment: "運氣評分：運氣稍差"), rangeDescription: NSLocalizedString("Range_SlightlyBad", comment: "最終分數描述：3 ~ 5")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_Average", comment: "運氣評分：普通水準"), rangeDescription: NSLocalizedString("Range_Average", comment: "最終分數描述：5 ~ 10")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_Fair", comment: "運氣評分：運氣尚可"), rangeDescription: NSLocalizedString("Range_Fair", comment: "最終分數描述：10 ~ 15")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_SmallBlessing", comment: "運氣評分：小吉"), rangeDescription: NSLocalizedString("Range_SmallBlessing", comment: "最終分數描述：15 ~ 30")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_MediumBlessing", comment: "運氣評分：中吉"), rangeDescription: NSLocalizedString("Range_MediumBlessing", comment: "最終分數描述：30 ~ 50")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_BigBlessing", comment: "運氣評分：大吉"), rangeDescription: NSLocalizedString("Range_BigBlessing", comment: "最終分數描述：50 ~ 100")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_VeryGood", comment: "運氣評分：運氣極好"), rangeDescription: NSLocalizedString("Range_VeryGood", comment: "最終分數描述：100 ~ 500")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_SuperGood", comment: "運氣評分：超級好運"), rangeDescription: NSLocalizedString("Range_SuperGood", comment: "最終分數描述：500 ~ 1000")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_Legendary", comment: "運氣評分：歐皇現世"), rangeDescription: NSLocalizedString("Range_Legendary", comment: "最終分數描述：1000 ~ 5000")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_God", comment: "運氣評分：運氣之神降臨"), rangeDescription: NSLocalizedString("Range_God", comment: "最終分數描述：5000 ~ 10000")),
        LuckLevelRange(label: NSLocalizedString("LuckLevel_GodProMax", comment: "運氣評分：運氣之神降臨ProMax"), rangeDescription: NSLocalizedString("Range_GodProMax", comment: "最終分數描述：final score ≥ 10000"))
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
            .navigationTitle("RatingStandards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @Environment(\.dismiss) var dismiss
}
