//
//  ResultSheet.swift
//  BoomOrBonus
//
//  02-screens-ux.md §5.2: headline, total, stage marks, unlock note, blessings, the copyable result text
//  the button matrix for both modes (daily rows added in Phase 4) and the record-break note (Phase 6).
//  Banner ads show on this sheet only (02 §12), mocked for now.
//

import SwiftUI

struct ResultSheet: View {
    let run: RunState
    let unlock: Int
    let deepest: Int
    var nextAttempt = 1          // 「再挑戰一次（第 N 次）」
    var broken: [(id: RecordID, value: Int)] = []     // records this run broke, with their final values
    let actions: Actions

    @State private var copied = false

    struct Actions {
        var sameDeck: () -> Void = {}
        var newRun: () -> Void = {}
        var endless: () -> Void = {}
        var changeLevel: () -> Void = {}
        var playLevel: (Int) -> Void = { _ in }
        var copy: () -> Void = {}
        var free: () -> Void = {}
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
        return head + Text(" · ")
            + (run.mode == .daily ? Text("今日挑戰第 \(run.attempt) 次") : Text("難度「\(Rules.difficulties[run.lv].name)」"))
    }

    private var title: String {
        Self.tiers[min(cleared, Self.tiers.count - 1)] + (allStretch ? " · " + String(localized: "全關超標") : "")
    }

    var body: some View {
        // The buttons are pinned under the scrolling summary (like the shop and the rules): they stay on screen
        // when a banner strip takes space on a small screen.
        SheetScaffold {
            list
        } footer: {
            VStack(spacing: 12) { buttons }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if !broken.isEmpty { recordNote }

            SheetBody(text: blessingsText)

            Text(verbatim: ShareText.make(run))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.sheetText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.sheetButton.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("result.shareText")

            if run.phase == .win {
                SheetBody(text: Text("可以帶著金幣、祝福和道具繼續打無盡關卡。無盡關卡沒有終點，每 2 關一個魔王，看能撐到第幾關。"))
            }

            if run.mode == .daily && run.phase != .win {
                SheetBody(text: Text("同一副牌在同樣的位置會發同樣的牌，哪張會爆也一樣。記住這次翻到的結果，下次就能避開。今日挑戰可以無限重打，紀錄會寫你第幾次破關。"))
                    .accessibilityIdentifier("result.dailyHint")
            }
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

    // MARK: Buttons (02 §5.2)
    //   win:             [複製戰績] [繼續無盡關卡 (primary)]
    //                    daily: [同一副牌再打] [去自由練習]   free: [挑戰難度「下一級」 或 再來一局] [同一副牌再打]
    //   daily not won:   [複製戰績] [去自由練習]   [再挑戰一次（第 N 次）(primary)]
    //   free not won:    [複製戰績] [換難度] [再來一局]   [同一副牌再打 (primary)]

    private var copyButton: some View {
        Button {
            copied = true
            actions.copy()
        } label: { Text(copied ? "已複製" : "複製戰績") }
            .buttonStyle(SheetButtonStyle())
            .accessibilityIdentifier("result.copy")
    }

    private var freeButton: some View {
        Button("去自由練習", action: actions.free)
            .buttonStyle(SheetButtonStyle())
            .accessibilityIdentifier("result.free")
    }

    @ViewBuilder
    private var buttons: some View {
        if run.phase == .win {
            HStack(spacing: 8) {
                copyButton
                Button("繼續無盡關卡", action: actions.endless)
                    .buttonStyle(SheetButtonStyle(primary: true))
                    .accessibilityIdentifier("result.endless")
            }
            .padding(.top, 4)
            HStack(spacing: 8) {
                if run.mode == .daily {
                    Button("同一副牌再打", action: actions.sameDeck)
                        .buttonStyle(SheetButtonStyle())
                        .accessibilityIdentifier("result.retry")
                    freeButton
                } else {
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
            }
        } else if run.mode == .daily {
            HStack(spacing: 8) {
                copyButton
                freeButton
            }
            .padding(.top, 4)
            Button { actions.sameDeck() } label: { Text("再挑戰一次（第 \(nextAttempt) 次）") }
                .buttonStyle(SheetButtonStyle(primary: true))
                .accessibilityIdentifier("result.retry")
        } else {
            HStack(spacing: 8) {
                copyButton
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

    /// 02 §5.2: 「這局打破 2 項個人紀錄：最長連中 9、單關最高分 120」, in the gold of the records page.
    private var recordNote: some View {
        let list = broken.map { $0.id.name + " " + Fmt.int($0.value) }.joined(separator: "、")
        return (Text("這局打破 \(broken.count) 項個人紀錄：") + Text(verbatim: list))
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(Theme.sheetText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Theme.gold.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("result.records")
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
