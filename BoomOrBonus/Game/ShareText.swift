//
//  ShareText.swift
//  BoomOrBonus
//
//  The copyable result text (02-screens-ux.md §5.2, prototype `shareText()`):
//
//    INTUITION++ 11/16 今日挑戰
//    第 3 次挑戰破關 · 總分 682
//    🟩🟨🟩🟩🟨🟩
//
//  🟩 cleared, 🟨 stretch, 🟥 failed, ⬜ not reached (endless stages extend the row).
//

import Foundation

enum ShareText {
    static func marksLine(_ marks: [Int]) -> String {
        (0..<max(Rules.STAGES, marks.count)).map { i -> String in
            guard i < marks.count else { return "⬜" }
            switch marks[i] {
            case 2: return "🟨"
            case 1: return "🟩"
            default: return "🟥"
            }
        }.joined()
    }

    static func make(_ run: RunState) -> String {
        let cleared = run.marks.filter { $0 > 0 }.count
        let won = run.marks.count >= Rules.STAGES && DailyRecord.isWin(run.marks)
        let daily = run.mode == .daily

        let head = "INTUITION++ \(DayKey.monthDay(run.day)) "
            + (daily ? String(localized: "今日挑戰")
                     : String(localized: "自由練習") + " · " + Rules.difficulties[run.lv].name)

        var result: String
        if daily {
            result = won ? String(localized: "第 \(run.attempt) 次挑戰破關")
                         : String(localized: "第 \(run.attempt) 次挑戰，止步第 \(run.stage) 關")
        } else if run.phase == .win {
            result = String(localized: "六關全破")
        } else if cleared >= Rules.STAGES {
            result = String(localized: "無盡模式打到第 \(cleared + 1) 關")
        } else {
            result = String(localized: "止步第 \(run.stage) 關")
        }
        if cleared > Rules.STAGES { result += String(localized: "，無盡 +\(cleared - Rules.STAGES) 關") }
        result += " · " + String(localized: "總分 \(Fmt.int(run.total))")

        return head + "\n" + result + "\n" + marksLine(run.marks)
    }
}
