//
//  OverviewTab.swift
//  BoomOrBonus
//
//  02-screens-ux.md §10.1: four tiles, the six records with their next target, and the cumulative numbers.
//

import SwiftUI

struct OverviewTab: View {
    let stats: Stats
    let unlock: Int
    let broken: [String]

    private func setOn(_ id: RecordID) -> String {
        stats.records[id].map { String(localized: "\(DayKey.monthDay($0.day)) 創下") } ?? ""
    }

    var body: some View {
        DashTiles {
            DashTile(label: Text(RecordID.total.name), value: dashNumber(stats.value(.total)),
                     sub: setOn(.total), id: "total")
            DashTile(label: Text(RecordID.streak.name), value: dashNumber(stats.value(.streak)),
                     sub: setOn(.streak), id: "streak")
            DashTile(label: Text(RecordID.deep.name), value: dashNumber(stats.value(.deep)),
                     sub: (stats.value(.deep) ?? 0) > Rules.STAGES
                        ? String(localized: "無盡多打 \((stats.value(.deep) ?? 0) - Rules.STAGES) 關") : setOn(.deep),
                     id: "deep")
            DashTile(label: Text("已解鎖難度"), value: Rules.difficultyName(min(max(unlock, 0), Rules.difficulties.count - 1)),
                     sub: String(localized: "共 \(Rules.difficulties.count) 級"), id: "unlock")
        }

        SheetLabel(text: Text("個人紀錄與下一個目標"))
        VStack(spacing: 0) {
            ForEach(RecordID.allCases, id: \.self) { id in
                RecordRow(id: id, entry: stats.records[id], progress: stats.progress(id),
                          justBroken: broken.contains(id.rawValue))
            }
        }

        SheetLabel(text: Text("累計"))
        totals
    }

    private var totals: some View {
        VStack(spacing: 6) {
            row(Text("總局數（含放棄 \(stats.abandons) 局）"), "\(stats.runs)", id: "runs")
            row(Text("破關率"), dashPercent(stats.clears, of: stats.runs), id: "clearRate")
            row(Text("選中率（\(stats.safe) / \(stats.picks) 手）"), dashPercent(stats.safe, of: stats.picks), id: "safeRate")
            row(Text("保命符擋下"), String(localized: "\(stats.shields) 次"), id: "shields")
            row(Text("全關超標"), String(localized: "\(stats.allSuper) 次"), id: "allSuper")
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(hex: 0xF0F1FA), in: RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ label: Text, _ value: String, id: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            label.foregroundStyle(Theme.sheetBody)
            Spacer(minLength: 8)
            Text(verbatim: value).font(Theme.number(13)).foregroundStyle(Theme.sheetText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dash.total.\(id)")
    }
}

/// One record: name, value, the milestone bar and 「下一個目標 500　3 / 5」. Gold with 「這局剛破」 when this run broke it.
struct RecordRow: View {
    let id: RecordID
    let entry: RecordEntry?
    let progress: MilestoneProgress
    let justBroken: Bool

    private var accent: Color { justBroken ? Color(hex: 0x9A6200) : Theme.sheetText }

    private var targetText: String {
        let count = "\(progress.achieved) / \(progress.total)"
        if let next = progress.next { return String(localized: "下一個目標 \(Fmt.int(next))") + "　" + count }
        return String(localized: "全部達成") + "　" + count
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: id.name + (justBroken ? "　" + String(localized: "這局剛破") : ""))
                    .font(.system(size: 13, weight: justBroken ? .bold : .regular))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text(verbatim: dashNumber(entry?.value))
                    .font(Theme.number(16))
                    .foregroundStyle(accent)
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.sheetButton)
                        Capsule().fill(justBroken ? Theme.gold : Theme.sheetPrimary)
                            .frame(width: geo.size.width * progress.fraction)
                    }
                }
                .frame(height: 6)
                Text(verbatim: targetText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.sheetMuted)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xDDDFEE)).frame(height: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Fmt.join([id.name + " " + dashNumber(entry?.value), targetText]
                                                 + (justBroken ? [String(localized: "這局剛破")] : []))))
        .accessibilityIdentifier(justBroken ? "rec.row.\(id.rawValue).new" : "rec.row.\(id.rawValue)")
    }
}
