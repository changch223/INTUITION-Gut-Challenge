//
//  BlessingsTab.swift
//  BoomOrBonus
//
//  02-screens-ux.md §10.4: per blessing the runs it was carried, the clears and the clear rate, most carried first.
//

import SwiftUI

struct BlessingsTab: View {
    let stats: Stats

    /// By runs, most first; ties keep the shop order.
    private var rows: [(id: BlessingID, tally: Stats.BlessingTally)] {
        BlessingID.allCases.enumerated()
            .compactMap { i, id in stats.byBlessing[id].map { (i, id, $0) } }
            .sorted { $0.2.runs != $1.2.runs ? $0.2.runs > $1.2.runs : $0.0 < $1.0 }
            .map { ($0.1, $0.2) }
    }

    var body: some View {
        if rows.isEmpty {
            SheetBody(text: Text("還沒買過祝福。過關後在商店買的祝福，會記錄帶著它打了幾局、破關幾次。"))
                .accessibilityIdentifier("dash.blessings.empty")
        } else {
            DashTable {
                GridRow {
                    Text("祝福").bold()
                    Text("帶過幾局").bold()
                    Text("破關").bold()
                    Text("破關率").bold()
                }
                .foregroundStyle(Theme.sheetMuted)
                ForEach(rows, id: \.id) { r in
                    GridRow {
                        Text(verbatim: r.id.displayName)
                            .accessibilityLabel(Text(verbatim: Fmt.join([r.id.displayName, String(localized: "帶過 \(r.tally.runs) 局，破關 \(r.tally.wins) 次，破關率 ") + dashPercent(r.tally.wins, of: r.tally.runs)])))
                            .accessibilityIdentifier("dash.blessing.\(r.id.rawValue)")
                        Text(verbatim: "\(r.tally.runs)").font(Theme.number(13))
                        Text(verbatim: "\(r.tally.wins)").font(Theme.number(13))
                        Text(verbatim: dashPercent(r.tally.wins, of: r.tally.runs)).font(Theme.number(13))
                    }
                }
            }
            SheetBody(text: Text("局數少的時候破關率會跳很大，打越多越準。"))
        }
    }
}
