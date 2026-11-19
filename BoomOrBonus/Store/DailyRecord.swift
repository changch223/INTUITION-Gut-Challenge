//
//  DailyRecord.swift
//  BoomOrBonus
//
//  The daily challenge ledger (03-data-persistence.md §3): one DailyRecord per day, the update rule that
//  runs when a run ends, and the derived numbers for the records page (Phase 6). Foundation only,
//  no Date() outside `DayKey.today`, so tests can control the day.
//

import Foundation

// MARK: - Day keys

/// A day as the integer `YYYYMMDD` in the user's local time zone (decided: local, not UTC).
/// Always the Gregorian calendar, so a Japanese or Buddhist system calendar cannot change the number.
enum DayKey {
    typealias Provider = () -> Int

    static func gregorian(timeZone: TimeZone = .current) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    static func from(_ date: Date, calendar: Calendar = gregorian()) -> Int {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return (p.year ?? 0) * 10000 + (p.month ?? 0) * 100 + (p.day ?? 0)
    }

    /// The real clock. Tests and the `-today` hook inject a different `Provider`.
    static func today() -> Int { from(Date()) }

    static func date(_ day: Int, calendar: Calendar = gregorian()) -> Date? {
        calendar.date(from: DateComponents(year: day / 10000, month: day / 100 % 100, day: day % 100, hour: 12))
    }

    /// `day` moved by `n` calendar days (negative = earlier). Month ends and leap years are the calendar's job.
    static func adding(_ n: Int, to day: Int, calendar: Calendar = gregorian()) -> Int {
        guard let d = date(day, calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: n, to: d) else { return day }
        return from(moved, calendar: calendar)
    }

    /// 20261116 -> "11/16" (the top-bar chip and the share text).
    static func monthDay(_ day: Int) -> String { "\(day / 100 % 100)/\(day % 100)" }

    /// `-today YYYYMMDD` (Debug builds only). Only honoured together with `-seed` or `-qaSave`, so a fake
    /// date can never write into the real `save-v6.json`.
    static func debugToday(arguments: [String] = ProcessInfo.processInfo.arguments) -> Int? {
        #if DEBUG
        guard arguments.contains("-seed") || arguments.contains("-qaSave"),
              let i = arguments.firstIndex(of: "-today"), i + 1 < arguments.count,
              let day = Int(arguments[i + 1]), date(day) != nil, from(date(day)!) == day else { return nil }
        return day
        #else
        return nil
        #endif
    }
}

// MARK: - DailyRecord

struct DailyRecord: Codable, Equatable {
    /// One finished attempt: stages cleared and the total it ended with (bar chart in Phase 6).
    struct Attempt: Codable, Equatable {
        var cleared: Int
        var total: Int
    }

    var tries = 0                // attempts so far, abandons included
    var win = false              // cleared today at least once
    var winTry = 0               // which attempt cleared it first (0 until then)
    var total = -1               // representative total; -1 = nothing recorded yet (so a 0 still registers)
    var marks: [Int] = []        // stage marks of the representative run
    var hist: [Attempt] = []     // one entry per attempt

    init() {}

    private enum CodingKeys: String, CodingKey { case tries, win, winTry, total, marks, hist }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tries = max(0, try c.decodeIfPresent(Int.self, forKey: .tries) ?? 0)
        win = try c.decodeIfPresent(Bool.self, forKey: .win) ?? false
        winTry = try c.decodeIfPresent(Int.self, forKey: .winTry) ?? 0
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? -1
        marks = try c.decodeIfPresent([Int].self, forKey: .marks) ?? []
        hist = try c.decodeIfPresent([Attempt].self, forKey: .hist) ?? []
    }

    /// The first six stages are all cleared (marks 1 or 2). Endless stages after that do not matter.
    static func isWin(_ marks: [Int]) -> Bool {
        let six = marks.prefix(Rules.STAGES)
        return six.count == Rules.STAGES && six.allSatisfy { $0 > 0 }
    }

    /// The update of 03 §3, called whenever a daily run ends (`finish`).
    /// - The first call for a run adds one try and one `hist` entry and sets `run.dailyCounted`.
    ///   A later call for the same run (endless ending after a clear) only refreshes total and marks.
    /// - A clear sets `win` / `winTry` once. The representative run is the best total before a clear,
    ///   and the best clearing run after it.
    mutating func finish(_ run: inout RunState) {
        let won = Self.isWin(run.marks)
        let attempt = max(1, run.attempt)
        if !run.dailyCounted {
            tries = max(tries, attempt)
            hist.append(Attempt(cleared: run.marks.filter { $0 > 0 }.count, total: run.total))
            run.dailyCounted = true
        }
        if won && !win {
            win = true
            winTry = attempt
            marks = run.marks
            total = run.total
        } else if !win && run.total > total {
            marks = run.marks
            total = run.total
        } else if win && won && run.total > total {
            marks = run.marks
            total = run.total
        }
    }
}

// MARK: - Derived numbers (03 §3.2)

enum DailyStats {
    /// Days with at least one finished attempt.
    static func playedDays(_ log: [Int: DailyRecord]) -> Int { log.count }

    static func clearedDays(_ log: [Int: DailyRecord]) -> Int { log.values.filter(\.win).count }

    private static func clearTries(_ log: [Int: DailyRecord]) -> [Int] {
        log.values.filter(\.win).map { max(1, $0.winTry) }
    }

    /// Fewest attempts it took to clear a day, nil when no day was cleared.
    static func fewestTries(_ log: [Int: DailyRecord]) -> Int? { clearTries(log).min() }

    /// Average attempts to clear, over cleared days only.
    static func averageTries(_ log: [Int: DailyRecord]) -> Double? {
        let t = clearTries(log)
        return t.isEmpty ? nil : Double(t.reduce(0, +)) / Double(t.count)
    }

    /// Consecutive cleared days counted back from today; while today is not cleared, from yesterday.
    static func currentStreak(_ log: [Int: DailyRecord], today: Int, calendar: Calendar = DayKey.gregorian()) -> Int {
        var day = today
        if log[day]?.win != true { day = DayKey.adding(-1, to: day, calendar: calendar) }
        var n = 0
        while log[day]?.win == true {
            n += 1
            day = DayKey.adding(-1, to: day, calendar: calendar)
        }
        return n
    }

    /// Longest run of cleared days in the 400 days ending today.
    static func longestStreak(_ log: [Int: DailyRecord], today: Int, calendar: Calendar = DayKey.gregorian()) -> Int {
        var best = 0, run = 0
        var day = today
        for _ in 0..<400 {
            if log[day]?.win == true {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
            day = DayKey.adding(-1, to: day, calendar: calendar)
        }
        return best
    }
}
