import SwiftUI

struct IntuitionLevelRange: Identifiable {
    let id = UUID()
    let label: String
    let rangeDescription: String
}

struct IntuitionLevelStandardsView: View {
   
    // 依據最終分數定義評分標準，直觀顯示門檻
    let levels: [IntuitionLevelRange] = [
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_VeryBad", comment: "直覺評分：直覺爆炸差"), rangeDescription: NSLocalizedString("Range_VeryBad", comment: "最終分數描述：final score < -50")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_ExtremelyBad", comment: "直覺評分：直覺極差"), rangeDescription: NSLocalizedString("Range_ExtremelyBad", comment: "最終分數描述：-50 ~ -10")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_Terrible", comment: "直覺評分：倒楣透頂"), rangeDescription: NSLocalizedString("Range_Terrible", comment: "最終分數描述：-10 ~ 0")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_Bad", comment: "直覺評分：直覺不佳"), rangeDescription: NSLocalizedString("Range_Bad", comment: "最終分數描述：0 ~ 3")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_SlightlyBad", comment: "直覺評分：直覺稍差"), rangeDescription: NSLocalizedString("Range_SlightlyBad", comment: "最終分數描述：3 ~ 5")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_Average", comment: "直覺評分：普通水準"), rangeDescription: NSLocalizedString("Range_Average", comment: "最終分數描述：5 ~ 10")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_Fair", comment: "直覺評分：直覺尚可"), rangeDescription: NSLocalizedString("Range_Fair", comment: "最終分數描述：10 ~ 15")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_SmallBlessing", comment: "直覺評分：小吉"), rangeDescription: NSLocalizedString("Range_SmallBlessing", comment: "最終分數描述：15 ~ 30")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_MediumBlessing", comment: "直覺評分：中吉"), rangeDescription: NSLocalizedString("Range_MediumBlessing", comment: "最終分數描述：30 ~ 50")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_BigBlessing", comment: "直覺評分：大吉"), rangeDescription: NSLocalizedString("Range_BigBlessing", comment: "最終分數描述：50 ~ 100")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_VeryGood", comment: "直覺評分：直覺極好"), rangeDescription: NSLocalizedString("Range_VeryGood", comment: "最終分數描述：100 ~ 500")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_SuperGood", comment: "直覺評分：超級好運"), rangeDescription: NSLocalizedString("Range_SuperGood", comment: "最終分數描述：500 ~ 1000")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_Legendary", comment: "直覺評分：歐皇現世"), rangeDescription: NSLocalizedString("Range_Legendary", comment: "最終分數描述：1000 ~ 5000")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_God", comment: "直覺評分：直覺之神降臨"), rangeDescription: NSLocalizedString("Range_God", comment: "最終分數描述：5000 ~ 10000")),
        IntuitionLevelRange(label: NSLocalizedString("IntuitionLevel_GodProMax", comment: "直覺評分：直覺之神降臨ProMax"), rangeDescription: NSLocalizedString("Range_GodProMax", comment: "最終分數描述：final score ≥ 10000"))
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
