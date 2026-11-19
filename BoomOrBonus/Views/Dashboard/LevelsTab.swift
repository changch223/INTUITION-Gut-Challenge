//
//  LevelsTab.swift
//  BoomOrBonus
//
//  02-screens-ux.md §10.3: runs, clears and best total per difficulty. The daily challenge is the first row;
//  difficulties that are not unlocked yet say 未解鎖.
//

import SwiftUI

struct LevelsTab: View {
    let stats: Stats
    let unlock: Int

    var body: some View {
        DashTable {
            GridRow {
                Text("難度").bold()
                Text("局數").bold()
                Text("破關").bold()
                Text("最高總分").bold()
            }
            .foregroundStyle(Theme.sheetMuted)
            tally(Text("今日挑戰"), stats.daily, id: "daily")
            ForEach(Array(Rules.difficulties.enumerated()), id: \.offset) { i, d in
                if i > unlock {
                    GridRow {
                        Text(verbatim: d.name)
                            .accessibilityLabel(Text(verbatim: d.name + "，" + String(localized: "未解鎖")))
                            .accessibilityIdentifier("dash.level.\(i)")
                        Text("未解鎖").foregroundStyle(Theme.sheetMuted).gridCellColumns(3)
                            .accessibilityHidden(true)
                    }
                } else {
                    tally(Text(verbatim: d.name), stats.byLevel.indices.contains(i) ? stats.byLevel[i] : Stats.Tally(), id: "\(i)")
                }
            }
        }
        SheetBody(text: Text("破關一個難度就解鎖下一個。今日挑戰的目標比「入門」高 30%。"))
    }

    private func tally(_ name: Text, _ t: Stats.Tally, id: String) -> some View {
        GridRow {
            name.accessibilityIdentifier("dash.level.\(id)")
            Text(verbatim: "\(t.runs)").font(Theme.number(13))
            Text(verbatim: "\(t.clears)").font(Theme.number(13))
            Text(verbatim: dashNumber(t.best)).font(Theme.number(13))
        }
    }
}
