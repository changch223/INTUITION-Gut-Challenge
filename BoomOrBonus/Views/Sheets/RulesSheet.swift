//
//  RulesSheet.swift
//  BoomOrBonus
//
//  The ? button opens this panel (02-screens-ux.md §2.1, §8, prototype showMenu): the full rules in a list that
//  scrolls, and the buttons pinned below it so they are on screen on an iPhone SE: sound on/off, 再看導覽,
//  選擇難度, 我的紀錄 (Phase 6), 放棄 (asks first, inside the sheet) and 回到遊戲.
//

import SwiftUI

struct RulesSheet: View {
    let mode: Mode
    let attempt: Int
    /// This mode's six stage targets (daily x1.3, level x1.15 already applied).
    let targets: [Int]
    let deepest: Int
    let muted: Bool
    let toggleMute: () -> Void
    let replayTour: () -> Void
    let openLevel: () -> Void
    let openRecords: () -> Void
    let abandon: () -> Void
    let close: () -> Void

    @State private var confirming = false

    var body: some View {
        SheetScaffold {
            VStack(alignment: .leading, spacing: 10) {
                SheetTitle(small: Text("INTUITION++"), big: Text("規則"))
                    .accessibilityIdentifier("rules.title")

                SheetBody(text: Text("每關在手數內把分數打到目標就能過關，下一關從 0 開始，各關分數加起來是最後的總分。每張牌獨立判定會不會爆，爆了只扣一手。連中一次得分多 25%，最高 2 倍；連中會帶到下一關，爆一次就歸零。"))

                SheetBody(text: Text(mode == .daily ? "今日挑戰的六關目標：" : "這個難度的六關目標：")
                    + Text(verbatim: targets.map { Fmt.int($0) }.joined(separator: "、"))
                    + Text("。第 2、4、6 關是魔王關，其他每一關都會抽一條特殊規則。"))
                    .accessibilityIdentifier("rules.targets")

                SheetLabel(text: Text("今日挑戰"))
                SheetBody(text: Text("每天換一副牌，所有人拿到的牌和規則都一樣。目標比「入門」高 30%，第一次很難過，但可以無限重打：同樣的位置會發同樣的牌，哪張會爆也一樣，記住結果就能越打越遠。紀錄寫的是你第幾次破關。"))

                SheetLabel(text: Text("危險度"))
                dangerTable

                SheetLabel(text: Text("每關的特殊規則"))
                modList

                SheetLabel(text: Text("金幣怎麼算"))
                calc([
                    (Text("過關基本"), "$3"),
                    (Text("剩下的每一手"), "+$1"),
                    (Text("總分打到超標線（目標 ×1.5）"), "+$3"),
                    (Text("祝福「利息」：每持有 $5"), String(localized: "+$1，最多 $3")),
                ])
                SheetBody(text: Text("例：第 1 關目標 18、超標線 27。用 4 手打到 28 分就過關，剩 3 手：$3 + $3 + $3 = $9。"))

                SheetLabel(text: Text("拚超標的獎勵"))
                SheetBody(text: Text("多 $3，戰績格變金色，前六關都超標拿到「全關超標」稱號，多打的分數也算進總分。代價是每多用一手少 $1，也多一次爆炸的風險。"))

                SheetLabel(text: Text("保命符"))
                SheetBody(text: Text("不用按。選到會爆的牌時自動擋下：這手不算、不扣手數，連中也不會斷。開局送 1 張，商店 $4 一張。"))

                SheetLabel(text: Text("破關之後"))
                SheetBody(text: Text("可以接著打無盡關卡，沒有終點，每 2 關一個魔王，看能撐到第幾關。破關也會解鎖下一個難度，共六級，點上方的日期或難度標籤切換。")
                    + (deepest > Rules.STAGES ? Text("你的無盡紀錄：第 \(deepest + 1) 關。") : Text(verbatim: "")))
            }
        } footer: {
            // Pinned outside the scroll area so the confirmation can never be clipped (iPhone SE).
            if confirming {
                confirmation
            } else {
                buttons
            }
        }
    }

    /// Small buttons in two columns, the last row ends with the primary one: keeps the rules list tall enough on an iPhone SE.
    private var buttons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: toggleMute) { Text(muted ? "開啟音效" : "關閉音效") }
                    .accessibilityIdentifier("rules.mute")
                Button(action: replayTour) { Text("再看導覽") }
                    .accessibilityIdentifier("rules.tour")
            }
            .buttonStyle(SheetButtonStyle(height: 42))
            HStack(spacing: 8) {
                Button(action: openLevel) { Text("選擇難度") }
                    .accessibilityIdentifier("rules.level")
                Button(action: openRecords) { Text("我的紀錄") }
                    .accessibilityIdentifier("rules.records")
            }
            .buttonStyle(SheetButtonStyle(height: 42))
            HStack(spacing: 8) {
                Button { confirming = true } label: { Text(mode == .daily ? "放棄（算一次）" : "放棄重來") }
                    .buttonStyle(SheetButtonStyle(height: 46))
                    .accessibilityIdentifier("rules.abandon")
                Button("回到遊戲", action: close)
                    .buttonStyle(SheetButtonStyle(primary: true, height: 46))
                    .accessibilityIdentifier("rules.close")
            }
        }
    }

    // MARK: Pieces

    private var dangerTable: some View {
        VStack(spacing: 5) {
            tableRow(Text("危險度"), Text("爆炸機率"), Text("倍數牌"), header: true)
            ForEach(0..<Rules.P.count, id: \.self) { i in
                tableRow(Text("\(i + 1) 格"),
                         Text(verbatim: "\(Int((Rules.P[i] * 100).rounded()))%"),
                         Rules.MUL[i] > 0 ? Text(verbatim: "×" + Fmt.num(Rules.MUL[i])) : Text("不出現"),
                         header: false)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.sheetText)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color(hex: 0xF0F1FA), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("rules.dangerTable")
    }

    private func tableRow(_ a: Text, _ b: Text, _ c: Text, header: Bool) -> some View {
        HStack {
            a.frame(maxWidth: .infinity, alignment: .leading)
            b.frame(maxWidth: .infinity, alignment: .leading)
            c.frame(maxWidth: .infinity, alignment: .leading)
        }
        .fontWeight(header ? .bold : .regular)
        .foregroundStyle(header ? Theme.sheetMuted : Theme.sheetText)
    }

    private var modList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ModID.allCases, id: \.self) { m in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: m.name).fontWeight(.bold).frame(width: 58, alignment: .leading)
                    Text(verbatim: m.desc).foregroundStyle(Theme.sheetBody).frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.sheetText)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color(hex: 0xF0F1FA), in: RoundedRectangle(cornerRadius: 12))
    }

    private func calc(_ rows: [(Text, String)]) -> some View {
        VStack(spacing: 5) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(alignment: .firstTextBaseline) {
                    r.0.foregroundStyle(Theme.sheetBody)
                    Spacer(minLength: 8)
                    Text(verbatim: r.1).font(Theme.number(13))
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.sheetText)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color(hex: 0xF0F1FA), in: RoundedRectangle(cornerRadius: 12))
    }

    /// Inline confirmation, so it can never be clipped or hidden behind a system alert.
    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 10) {
            SheetBody(text: mode == .daily
                ? Text("放棄這次挑戰？這次會算一次挑戰（即使一手都還沒選），接著開始第 \(attempt + 1) 次。")
                : Text("放棄這局？會換一副新牌重新開始。"))
                .fontWeight(.bold)
                .accessibilityIdentifier("rules.confirmText")
            HStack(spacing: 8) {
                Button("再想想") { confirming = false }
                    .buttonStyle(SheetButtonStyle())
                    .accessibilityIdentifier("rules.abandonCancel")
                Button("放棄", action: abandon)
                    .buttonStyle(SheetButtonStyle(primary: true))
                    .accessibilityIdentifier("rules.abandonConfirm")
            }
        }
    }
}
