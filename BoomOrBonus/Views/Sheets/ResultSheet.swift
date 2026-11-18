//
//  ResultSheet.swift
//  BoomOrBonus
//
//  02-screens-ux.md §5.2 for free play: headline, total, stage marks, unlock note, blessings and the
//  button matrix. Copy-result text (Phase 4) and the record-break note (Phase 6) are not here yet.
//  Banner ads show on this sheet only (02 §12), mocked for now.
//

import SwiftUI

struct ResultSheet: View {
    let run: RunState
    let unlock: Int
    let deepest: Int
    let actions: Actions

    struct Actions {
        var sameDeck: () -> Void = {}
        var newRun: () -> Void = {}
        var endless: () -> Void = {}
        var changeLevel: () -> Void = {}
        var playLevel: (Int) -> Void = { _ in }
    }

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

            SheetBody(text: summary)
                .accessibilityIdentifier("result.summary")

            if let lv = run.newlyUnlockedLevel, run.phase == .win {
                let d = Rules.difficulties[lv]
                Text("解鎖新難度「\(d.name)」：\(d.desc)。難度會累加，前面的規則也一起生效。")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.sheetText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Theme.mint.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("result.unlock")
            }

            SheetBody(text: blessingsText)

            if run.phase == .win {
                SheetBody(text: Text("可以帶著金幣、祝福和道具繼續打無盡關卡。無盡關卡沒有終點，每 2 關一個魔王，看能撐到第幾關。"))
            }

            buttons

            MockBannerView()
        }
    }

    /// 說明: marks legend, stretch count, endless extras.
    private var summary: Text {
        var t = Text("綠色是過關，金色是超標。前六關超標 \(stretchCount) / \(Rules.STAGES)")
        if cleared > Rules.STAGES { t = t + Text("，無盡關卡多打了 \(cleared - Rules.STAGES) 關") }
        t = t + Text("。")
        if deepest > Rules.STAGES { t = t + Text("無盡最遠紀錄：第 \(deepest + 1) 關。") }
        return t
    }

    // MARK: Buttons (02 §5.2, free play)
    //   win:      [繼續無盡關卡]   [挑戰難度「下一級」 或 再來一局] [同一副牌再打]
    //   not won:  [換難度] [再來一局]   [同一副牌再打 (primary)]

    @ViewBuilder
    private var buttons: some View {
        if run.phase == .win {
            Button("繼續無盡關卡", action: actions.endless)
                .buttonStyle(SheetButtonStyle(primary: true))
                .accessibilityIdentifier("result.endless")
                .padding(.top, 4)
            HStack(spacing: 8) {
                let next = run.lv + 1
                if next < Rules.difficulties.count && next <= unlock {
                    Button { actions.playLevel(next) } label: { Text("挑戰難度「\(Rules.difficulties[next].name)」") }
                        .buttonStyle(SheetButtonStyle())
                        .accessibilityIdentifier("result.nextLevel")
                } else {
                    Button("再來一局", action: actions.newRun)
                        .buttonStyle(SheetButtonStyle())
                        .accessibilityIdentifier("result.new")
                }
                Button("同一副牌再打", action: actions.sameDeck)
                    .buttonStyle(SheetButtonStyle())
                    .accessibilityIdentifier("result.retry")
            }
        } else {
            HStack(spacing: 8) {
                Button("換難度", action: actions.changeLevel)
                    .buttonStyle(SheetButtonStyle())
                    .accessibilityIdentifier("result.changeLevel")
                Button("再來一局", action: actions.newRun)
                    .buttonStyle(SheetButtonStyle())
                    .accessibilityIdentifier("result.new")
            }
            .padding(.top, 4)
            Button("同一副牌再打", action: actions.sameDeck)
                .buttonStyle(SheetButtonStyle(primary: true))
                .accessibilityIdentifier("result.retry")
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
