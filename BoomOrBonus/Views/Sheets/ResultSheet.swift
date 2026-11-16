//
//  ResultSheet.swift
//  BoomOrBonus
//
//  Simple version of 02-screens-ux.md §5.2: headline, total, stage marks, 再來一局.
//  Share text, unlock note, record break note and the full button set come in later phases.
//

import SwiftUI

struct ResultSheet: View {
    let run: RunState
    let playAgain: () -> Void

    private static let tiers = ["直覺迷路了", "感覺不太靈", "普通水準", "小有靈感", "預感強到爆", "神準直覺", "歐皇現世"]

    private var cleared: Int { run.marks.filter { $0 > 0 }.count }
    private var firstSix: [Int] { Array(run.marks.prefix(Rules.STAGES)) }
    private var allStretch: Bool { firstSix.count == Rules.STAGES && firstSix.allSatisfy { $0 == 2 } }
    private var stretchCount: Int { firstSix.filter { $0 == 2 }.count }

    private var headline: Text {
        let head: Text
        if run.phase == .win {
            head = Text("六關全破")
        } else if cleared >= Rules.STAGES {
            head = Text("無盡模式止步第 \(run.stage) 關")
        } else {
            head = Text("止步第 \(run.stage) 關")
        }
        return head + Text(" · ") + Text("難度「\(Rules.difficulties[run.lv].name)」")
    }

    private var title: String {
        Self.tiers[min(cleared, Self.tiers.count - 1)] + (allStretch ? " · " + String(localized: "全關超標") : "")
    }

    var body: some View {
        SheetContainer {
            SheetTitle(small: headline, big: Text(verbatim: title))

            Text(Fmt.int(run.total))
                .font(Theme.number(54))
                .tracking(-1)
                .foregroundStyle(Theme.sheetText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel("總分 \(run.total)")

            marks

            SheetBody(text: Text("綠色是過關，金色是超標。前六關超標 \(stretchCount) / \(Rules.STAGES)。"))

            SheetBody(text: blessingsText)

            Button("再來一局", action: playAgain)
                .buttonStyle(SheetButtonStyle(primary: true))
                .accessibilityIdentifier("result.again")
                .padding(.top, 4)
        }
    }

    private var blessingsText: Text {
        let owned = BlessingID.allCases.filter { run.has($0) }
        guard !owned.isEmpty else { return Text("這局沒有買祝福。") }
        let names = owned.map { run.level($0) > 1 ? "\($0.name) ×\(run.level($0))" : $0.name }.joined(separator: "、")
        return Text("這局帶的祝福：") + Text(verbatim: names)
    }

    /// One cell per stage: green 過 / gold 超 / red 敗, grey for stages not reached (endless extends right).
    private var marks: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(Rules.STAGES, run.marks.count), id: \.self) { i in
                let m: Int? = i < run.marks.count ? run.marks[i] : nil
                Group {
                    switch m {
                    case 2: Text("超")
                    case 1: Text("過")
                    case 0: Text("敗").foregroundStyle(.white)
                    default: Text(verbatim: "")
                    }
                }
                .font(Theme.number(12))
                .foregroundStyle(Theme.sheetText)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(markColor(m), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(markSummary)
    }

    private func markColor(_ m: Int?) -> Color {
        switch m {
        case 2: return Theme.gold
        case 1: return Theme.mint
        case 0: return Theme.red
        default: return Theme.sheetButton
        }
    }

    private var markSummary: String {
        let words = run.marks.enumerated().map { i, m in
            String(localized: "第 \(i + 1) 關") + (m == 2 ? String(localized: "超標") : m == 1 ? String(localized: "過關") : String(localized: "失敗"))
        }
        return words.joined(separator: "，")
    }
}
