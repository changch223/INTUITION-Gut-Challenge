//
//  DailyTab.swift
//  BoomOrBonus
//
//  02-screens-ux.md §10.2: four numbers (03 §3.2, DailyStats), today's attempts as a bar chart (stages cleared,
//  the clearing attempt in green, at most the last 8) and a 14-day calendar in 7 columns.
//  Both are plain SwiftUI shapes with fixed row heights so they hold their layout on an iPhone SE.
//

import SwiftUI

struct DailyTab: View {
    let log: [Int: DailyRecord]
    let today: Int

    private let chartHeight: CGFloat = 66

    var body: some View {
        let played = DailyStats.playedDays(log)
        let wins = DailyStats.clearedDays(log)
        let streak = DailyStats.currentStreak(log, today: today)
        let best = DailyStats.longestStreak(log, today: today)
        let fewest = DailyStats.fewestTries(log)
        let average = DailyStats.averageTries(log)

        DashTiles {
            DashTile(label: Text("破關天數"), value: "\(wins) / \(played)", sub: String(localized: "玩過的天數"), id: "wins")
            DashTile(label: Text("連續破關"), value: String(localized: "\(streak) 天"),
                     sub: String(localized: "最長 \(best) 天"), id: "streak")
            DashTile(label: Text("最少幾次破關"), value: fewest.map { String(localized: "第 \($0) 次") } ?? "—", sub: "", id: "fewest")
            DashTile(label: Text("平均幾次破關"), value: average.map { String(localized: "\(Fmt.dec1($0)) 次") } ?? "—",
                     sub: "", id: "average")
        }

        SheetLabel(text: Text("今天每一次打到哪裡"))
        tries

        SheetLabel(text: Text("最近 14 天"))
        calendar
        SheetBody(text: Text("綠格的數字是第幾次破關，紅框的「×3」是挑戰 3 次還沒破，空白是沒玩。"))
    }

    // MARK: Today's attempts

    @ViewBuilder
    private var tries: some View {
        if let record = log[today], !record.hist.isEmpty {
            let shown = Array(record.hist.suffix(8))
            let offset = record.hist.count - shown.count
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(shown.enumerated()), id: \.offset) { i, a in
                    let cleared = a.cleared >= Rules.STAGES
                    VStack(spacing: 4) {
                        VStack(spacing: 3) {
                            Text(verbatim: cleared ? String(localized: "破關") : String(localized: "\(a.cleared) 關"))
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(Theme.sheetText)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cleared ? Theme.mint : Theme.sheetPrimary)
                                .frame(width: 24,
                                       height: max(3, (CGFloat(min(a.cleared, Rules.STAGES)) / CGFloat(Rules.STAGES) * chartHeight).rounded()))
                        }
                        .frame(height: chartHeight + 16, alignment: .bottom)     // the label sits on its bar
                        Text(verbatim: String(localized: "第 \(offset + i + 1) 次"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.sheetMuted)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: 56)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: chartSummary(shown, offset: offset)))
            .accessibilityIdentifier("dash.tries")
            SheetBody(text: record.win
                ? Text("柱子是每次過了幾關，綠色是破關。今天在第 \(record.winTry) 次破關。")
                : Text("柱子是每次過了幾關，綠色是破關。今天已挑戰 \(record.tries) 次，還沒破關。"))
        } else {
            SheetBody(text: Text("今天還沒挑戰。"))
                .accessibilityIdentifier("dash.tries.empty")
        }
    }

    private func chartSummary(_ shown: [DailyRecord.Attempt], offset: Int) -> String {
        let parts = shown.enumerated().map { i, a in
            a.cleared >= Rules.STAGES ? String(localized: "第 \(offset + i + 1) 次破關")
                                      : String(localized: "第 \(offset + i + 1) 次過了 \(a.cleared) 關")
        }
        return String(localized: "今天每一次打到哪裡：\(Fmt.list(parts))")
    }

    // MARK: Calendar

    private var days: [Int] { (0..<14).reversed().map { DayKey.adding(-$0, to: today) } }

    private var calendar: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { day in cell(day) }
        }
        .accessibilityIdentifier("dash.calendar")
    }

    private func cell(_ day: Int) -> some View {
        let r = log[day]
        let md = DayKey.monthDay(day)
        let value: String = r.map { $0.win ? "\(max(1, $0.winTry))" : "×\(max(1, $0.tries))" } ?? ""
        let label: String = r.map {
            $0.win ? String(localized: "\(md) 第 \(max(1, $0.winTry)) 次破關")
                   : String(localized: "\(md) 挑戰 \(max(1, $0.tries)) 次未破")
        } ?? String(localized: "\(md) 未玩")
        let fill: Color = r?.win == true ? Theme.mint : (r != nil ? Color.white : Color(hex: 0xF0F1FA))
        return VStack(spacing: 2) {
            Text(verbatim: md).font(.system(size: 9.5)).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(r?.win == true ? Color(hex: 0x062A20) : Theme.sheetMuted)
            Text(verbatim: value).font(Theme.number(13)).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(r?.win == true ? Color(hex: 0x062A20) : Color(hex: 0xC21F3F))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(fill, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if r != nil, r?.win != true {
                RoundedRectangle(cornerRadius: 8).stroke(Theme.red, lineWidth: 1.5)
            }
        }
        .overlay {
            if day == today {
                RoundedRectangle(cornerRadius: 9).stroke(Theme.sheetText, lineWidth: 2).padding(-2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: day == today ? Fmt.join([label, String(localized: "今天")]) : label))
        .accessibilityIdentifier("dash.day.\(day)")
    }
}
