//
//  DailyRecordTests.swift
//  BoomOrBonusTests
//
//  Phase 4: the DailyRecord update rule (03 §3, all five rows of the §3.1 table together with
//  GameViewModelDailyTests), the derived numbers (§3.2), day keys, save compatibility and the share text.
//

import XCTest
@testable import BoomOrBonus

final class DailyRecordTests: XCTestCase {

    /// A finished daily run as `finish` sees it.
    private func run(attempt: Int, marks: [Int], total: Int, counted: Bool = false, day: Int = 20261116) -> RunState {
        var r = GameEngine.newRun(seed: UInt32(day), lv: 0, mode: .daily, targetMul: 1.3)
        r.day = day
        r.attempt = attempt
        r.marks = marks
        r.total = total
        r.dailyCounted = counted
        return r
    }

    private let six = [1, 2, 1, 1, 2, 1]

    // MARK: - Update rule

    func testFirstFinishCountsOneTryAndOneHistEntry() {
        var rec = DailyRecord()
        var r = run(attempt: 1, marks: [1, 1, 0], total: 30)
        rec.finish(&r)
        XCTAssertEqual(rec.tries, 1)
        XCTAssertEqual(rec.hist, [DailyRecord.Attempt(cleared: 2, total: 30)])
        XCTAssertTrue(r.dailyCounted)
        XCTAssertFalse(rec.win)
        XCTAssertEqual(rec.winTry, 0)
        XCTAssertEqual(rec.total, 30)
        XCTAssertEqual(rec.marks, [1, 1, 0])
    }

    func testSecondFinishOfTheSameRunDoesNotCountAgain() {
        var rec = DailyRecord()
        var r = run(attempt: 1, marks: [1, 0], total: 20)
        rec.finish(&r)
        rec.finish(&r)
        XCTAssertEqual(rec.tries, 1)
        XCTAssertEqual(rec.hist.count, 1)
    }

    func testTriesIsTheLargestAttemptNumber() {
        var rec = DailyRecord()
        var a = run(attempt: 4, marks: [0], total: 0)
        rec.finish(&a)
        XCTAssertEqual(rec.tries, 4)
        var b = run(attempt: 2, marks: [0], total: 0)       // lower number never lowers it
        rec.finish(&b)
        XCTAssertEqual(rec.tries, 4)
        XCTAssertEqual(rec.hist.count, 2)
    }

    func testAbandonWithZeroPicksStillCounts() {
        // Table row 3: 放棄（算一次）, even before the first pick: one failed stage, total 0.
        var rec = DailyRecord()
        var r = run(attempt: 1, marks: [0], total: 0)
        rec.finish(&r)
        XCTAssertEqual(rec.tries, 1)
        XCTAssertEqual(rec.hist, [DailyRecord.Attempt(cleared: 0, total: 0)])
        XCTAssertEqual(rec.total, 0, "a total of 0 still registers (sentinel is -1)")
        XCTAssertEqual(rec.marks, [0])
    }

    func testBeforeAClearTheRepresentativeRunIsTheHighestTotal() {
        var rec = DailyRecord()
        var a = run(attempt: 1, marks: [1, 0], total: 50); rec.finish(&a)
        var b = run(attempt: 2, marks: [0], total: 20); rec.finish(&b)
        XCTAssertEqual(rec.total, 50)
        XCTAssertEqual(rec.marks, [1, 0])
        var c = run(attempt: 3, marks: [1, 1, 0], total: 80); rec.finish(&c)
        XCTAssertEqual(rec.total, 80)
        XCTAssertEqual(rec.marks, [1, 1, 0])
        XCTAssertEqual(rec.tries, 3)
    }

    func testClearSetsWinAndWinTryAndTakesOverTheRepresentativeRun() {
        var rec = DailyRecord()
        var a = run(attempt: 1, marks: [1, 1, 1, 0], total: 999); rec.finish(&a)
        XCTAssertEqual(rec.total, 999)
        var w = run(attempt: 2, marks: six, total: 400); rec.finish(&w)
        XCTAssertTrue(rec.win)
        XCTAssertEqual(rec.winTry, 2)
        XCTAssertEqual(rec.total, 400, "after a clear the representative total is the clearing run, even if lower")
        XCTAssertEqual(rec.marks, six)
    }

    func testAfterAClearOnlyAHigherClearReplacesTheRepresentativeRun() {
        var rec = DailyRecord()
        var w = run(attempt: 1, marks: six, total: 400); rec.finish(&w)
        var fail = run(attempt: 2, marks: [1, 1, 1, 1, 1, 0], total: 5000); rec.finish(&fail)
        XCTAssertEqual(rec.total, 400, "a failed run never replaces a clear")
        var lower = run(attempt: 3, marks: six, total: 300); rec.finish(&lower)
        XCTAssertEqual(rec.total, 400)
        var higher = run(attempt: 4, marks: [2, 2, 2, 2, 2, 2], total: 700); rec.finish(&higher)
        XCTAssertEqual(rec.total, 700)
        XCTAssertEqual(rec.marks, [2, 2, 2, 2, 2, 2])
        XCTAssertEqual(rec.winTry, 1, "winTry stays the first clear")
        XCTAssertEqual(rec.tries, 4)
    }

    func testEndlessFinishAfterAClearOnlyUpdatesTotalAndMarks() {
        var rec = DailyRecord()
        var r = run(attempt: 3, marks: six, total: 400)
        rec.finish(&r)                                    // the clear
        XCTAssertEqual(rec.tries, 3)
        // Endless ends: same run object (dailyCounted already true), more stages, higher total.
        r.marks = six + [1, 1, 0]
        r.total = 900
        rec.finish(&r)
        XCTAssertEqual(rec.tries, 3)
        XCTAssertEqual(rec.hist.count, 1)
        XCTAssertEqual(rec.winTry, 3)
        XCTAssertEqual(rec.total, 900)
        XCTAssertEqual(rec.marks.count, 9)
    }

    func testIsWinNeedsAllSixStages() {
        XCTAssertTrue(DailyRecord.isWin(six))
        XCTAssertTrue(DailyRecord.isWin(six + [0]), "endless failure does not undo the clear")
        XCTAssertFalse(DailyRecord.isWin([1, 1, 1, 1, 1]))
        XCTAssertFalse(DailyRecord.isWin([1, 1, 1, 1, 1, 0]))
        XCTAssertFalse(DailyRecord.isWin([]))
    }

    // MARK: - Derived numbers

    private func day(_ n: Int, from today: Int = 20261116) -> Int { DayKey.adding(-n, to: today) }

    private func won(_ tries: Int) -> DailyRecord {
        var r = DailyRecord(); r.tries = tries; r.win = true; r.winTry = tries; return r
    }
    private func lost(_ tries: Int) -> DailyRecord {
        var r = DailyRecord(); r.tries = tries; return r
    }

    func testCountsFewestAndAverage() {
        let log: [Int: DailyRecord] = [1: won(3), 2: won(1), 3: lost(9), 4: won(5)]
        XCTAssertEqual(DailyStats.playedDays(log), 4)
        XCTAssertEqual(DailyStats.clearedDays(log), 3)
        XCTAssertEqual(DailyStats.fewestTries(log), 1)
        XCTAssertEqual(DailyStats.averageTries(log)!, 3.0, accuracy: 1e-9, "(3+1+5)/3, only cleared days")
    }

    func testEmptyLogHasNoClearNumbers() {
        XCTAssertEqual(DailyStats.playedDays([:]), 0)
        XCTAssertEqual(DailyStats.clearedDays([:]), 0)
        XCTAssertNil(DailyStats.fewestTries([:]))
        XCTAssertNil(DailyStats.averageTries([:]))
        XCTAssertEqual(DailyStats.currentStreak([:], today: 20261116), 0)
        XCTAssertEqual(DailyStats.longestStreak([:], today: 20261116), 0)
        XCTAssertNil(DailyStats.fewestTries([20261116: lost(3)]), "played but never cleared")
    }

    func testStreakCountsFromTodayWhenTodayIsCleared() {
        let t = 20261116
        let log = [t: won(2), day(1): won(1), day(2): won(4), day(4): won(1)]
        XCTAssertEqual(DailyStats.currentStreak(log, today: t), 3, "gap at day 3 stops it")
    }

    func testStreakCountsFromYesterdayWhileTodayIsNotCleared() {
        let t = 20261116
        XCTAssertEqual(DailyStats.currentStreak([day(1): won(1), day(2): won(1)], today: t), 2)
        XCTAssertEqual(DailyStats.currentStreak([t: lost(5), day(1): won(1), day(2): won(1)], today: t), 2,
                       "today played but not cleared yet is the same as not played")
        XCTAssertEqual(DailyStats.currentStreak([day(2): won(1)], today: t), 0, "yesterday missed: streak is over")
    }

    func testStreakCrossesMonthAndYearEnds() {
        let t = 20260102
        let log = [t: won(1), 20260101: won(1), 20251231: won(1), 20251130: won(1)]
        XCTAssertEqual(DailyStats.currentStreak(log, today: t), 3)
    }

    func testLongestStreakPicksTheBestRunWithGaps() {
        let t = 20261116
        var log: [Int: DailyRecord] = [:]
        for n in [0, 1, 2] { log[day(n)] = won(1) }          // 3 now
        for n in 10...16 { log[day(n)] = won(2) }            // 7 earlier
        log[day(18)] = won(1); log[day(19)] = lost(2)
        XCTAssertEqual(DailyStats.longestStreak(log, today: t), 7)
        XCTAssertEqual(DailyStats.currentStreak(log, today: t), 3)
    }

    func testLongestStreakScansExactly400Days() {
        let t = 20261116
        var log: [Int: DailyRecord] = [:]
        for n in 0..<450 { log[day(n)] = won(1) }
        XCTAssertEqual(DailyStats.longestStreak(log, today: t), 400, "the scan stops 400 days back")
        // A streak that ends exactly on the 400th day back is still seen; one day further is not.
        var edge: [Int: DailyRecord] = [:]
        for n in 395..<400 { edge[day(n)] = won(1) }
        XCTAssertEqual(DailyStats.longestStreak(edge, today: t), 5)
        XCTAssertEqual(DailyStats.longestStreak([day(400): won(1)], today: t), 0)
    }

    // MARK: - Day keys

    func testDayKeyFromDateUsesTheTimeZone() {
        // 14:30 UTC is 23:30 on the 16th in Tokyo and 06:30 on the 16th in Los Angeles.
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!, la = TimeZone(identifier: "America/Los_Angeles")!
        let date = ISO8601DateFormatter().date(from: "2026-11-16T14:30:00Z")!
        XCTAssertEqual(DayKey.from(date, calendar: DayKey.gregorian(timeZone: tokyo)), 20261116)
        XCTAssertEqual(DayKey.from(date, calendar: DayKey.gregorian(timeZone: la)), 20261116)
        let later = ISO8601DateFormatter().date(from: "2026-11-16T15:30:00Z")!       // 00:30 on the 17th in Tokyo
        XCTAssertEqual(DayKey.from(later, calendar: DayKey.gregorian(timeZone: tokyo)), 20261117)
        XCTAssertEqual(DayKey.from(later, calendar: DayKey.gregorian(timeZone: la)), 20261116)
    }

    func testDayKeyIgnoresNonGregorianSystemCalendars() {
        // The key must stay 2026xxxx even when the user's calendar is Japanese (Reiwa 8).
        let date = ISO8601DateFormatter().date(from: "2026-11-16T03:00:00Z")!
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertNotEqual(japanese.component(.year, from: date), 2026)
        XCTAssertEqual(DayKey.from(date, calendar: DayKey.gregorian(timeZone: TimeZone(identifier: "Asia/Tokyo")!)), 20261116)
    }

    func testDayArithmeticHandlesMonthEndsAndLeapYears() {
        XCTAssertEqual(DayKey.adding(-1, to: 20240301), 20240229)
        XCTAssertEqual(DayKey.adding(-1, to: 20250301), 20250228)
        XCTAssertEqual(DayKey.adding(-1, to: 20260101), 20251231)
        XCTAssertEqual(DayKey.adding(1, to: 20261231), 20270101)
        let tw = Locale(identifier: "zh_TW")
        XCTAssertEqual(DayKey.monthDay(20261116, locale: tw), "11/16")
        XCTAssertEqual(DayKey.monthDay(20260105, locale: tw), "1/5")
        // Short month-day order of each UI language.
        XCTAssertEqual(DayKey.monthDay(20260105, locale: Locale(identifier: "en")), "1/5")
        XCTAssertEqual(DayKey.monthDay(20260105, locale: Locale(identifier: "ja")), "1/5")
        XCTAssertEqual(DayKey.monthDay(20260105, locale: Locale(identifier: "zh-Hans")), "1/5")
        XCTAssertEqual(DayKey.monthDay(20260105, locale: Locale(identifier: "zh-HK")), "5/1")
        XCTAssertEqual(DayKey.monthDay(20261116, locale: Locale(identifier: "ru")), "16.11")
    }

    func testDebugTodayNeedsAnIsolatedSaveAndAValidDate() {
        XCTAssertEqual(DayKey.debugToday(arguments: ["-seed", "1", "-today", "20261116"]), 20261116)
        XCTAssertEqual(DayKey.debugToday(arguments: ["-qaSave", "-today", "20270102"]), 20270102)
        XCTAssertNil(DayKey.debugToday(arguments: ["-today", "20261116"]), "never against the real save")
        XCTAssertNil(DayKey.debugToday(arguments: ["-seed", "1", "-today", "20261340"]))
        XCTAssertNil(DayKey.debugToday(arguments: ["-seed", "1", "-today", "abc"]))
        XCTAssertNil(DayKey.debugToday(arguments: ["-seed", "1"]))
    }

    // MARK: - Save format

    func testOldSaveWithoutDailyFieldsStillDecodes() throws {
        let json = #"{"unlock":3,"lastLevel":2,"deepest":9,"muted":false,"onboardingDone":true,"runs":{}}"#
        let d = try JSONDecoder().decode(SaveData.self, from: Data(json.utf8))
        XCTAssertEqual(d.unlock, 3)
        XCTAssertTrue(d.daily.isEmpty)
        XCTAssertNil(d.mode)
    }

    func testDailyRoundTripsWithDayStringKeys() throws {
        var d = SaveData()
        var rec = DailyRecord()
        var r = run(attempt: 2, marks: six, total: 412)
        rec.finish(&r)
        d.daily[20261116] = rec
        d.mode = .daily
        let raw = try JSONEncoder().encode(d)
        let text = String(decoding: raw, as: UTF8.self)
        XCTAssertTrue(text.contains("\"20261116\""), text)
        XCTAssertEqual(try JSONDecoder().decode(SaveData.self, from: raw), d)
    }

    func testOneBrokenDayDoesNotDropTheOthers() throws {
        let json = #"{"daily":{"20261115":{"tries":2,"win":true,"winTry":2,"total":300,"marks":[1,1,1,1,1,1],"hist":[]},"20261116":"garbage","x":{"tries":1}}}"#
        let d = try JSONDecoder().decode(SaveData.self, from: Data(json.utf8))
        XCTAssertEqual(d.daily.keys.sorted(), [20261115])
        XCTAssertEqual(d.daily[20261115]?.winTry, 2)
    }

    // MARK: - Share text (02 §5.2)

    func testDailyWinShareTextMatchesTheSpecExample() {
        var r = run(attempt: 3, marks: [1, 2, 1, 1, 2, 1], total: 682)
        r.phase = .win
        XCTAssertEqual(ShareText.make(r), "INTUITION++ 11/16 今日挑戰\n第 3 次挑戰破關 · 總分 682\n🟩🟨🟩🟩🟨🟩")
    }

    func testDailyFailShareText() {
        var r = run(attempt: 2, marks: [1, 2, 0], total: 1234)
        r.stage = 3
        r.phase = .over
        XCTAssertEqual(ShareText.make(r), "INTUITION++ 11/16 今日挑戰\n第 2 次挑戰，止步第 3 關 · 總分 1,234\n🟩🟨🟥⬜⬜⬜")
    }

    func testEndlessMarksExtendTheRow() {
        var r = run(attempt: 1, marks: six + [1, 0], total: 900)
        r.stage = 8
        r.phase = .over
        XCTAssertEqual(ShareText.make(r), "INTUITION++ 11/16 今日挑戰\n第 1 次挑戰破關，無盡 +1 關 · 總分 900\n🟩🟨🟩🟩🟨🟩🟩🟥")
    }

    func testFreeShareTexts() {
        var r = GameEngine.newRun(seed: 5, lv: 1, mode: .free)
        r.day = 20261116
        r.marks = six
        r.total = 500
        r.phase = .win
        XCTAssertEqual(ShareText.make(r), "INTUITION++ 11/16 自由練習 · 進階\n六關全破 · 總分 500\n🟩🟨🟩🟩🟨🟩")
        r.marks = [1, 0]
        r.stage = 2
        r.phase = .over
        XCTAssertEqual(ShareText.make(r), "INTUITION++ 11/16 自由練習 · 進階\n止步第 2 關 · 總分 500\n🟩🟥⬜⬜⬜⬜")
        r.marks = six + [1, 1, 0]
        r.stage = 9
        XCTAssertEqual(ShareText.make(r), "INTUITION++ 11/16 自由練習 · 進階\n無盡模式打到第 9 關，無盡 +2 關 · 總分 500\n🟩🟨🟩🟩🟨🟩🟩🟩🟥")
    }

    func testAbandonedZeroPickRunShareText() {
        var r = run(attempt: 1, marks: [0], total: 0)
        r.phase = .over
        XCTAssertEqual(ShareText.make(r), "INTUITION++ 11/16 今日挑戰\n第 1 次挑戰，止步第 1 關 · 總分 0\n🟥⬜⬜⬜⬜⬜")
    }
}
