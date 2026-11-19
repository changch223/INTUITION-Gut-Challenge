//
//  StatsTests.swift
//  BoomOrBonusTests
//
//  Phase 6: the Stats value type (03 §4): the strict > record rule, the milestone math, the counters,
//  backward-compatible decoding and the sample data.
//

import XCTest
@testable import BoomOrBonus

final class StatsTests: XCTestCase {

    // MARK: Records (03 §4.2)

    func testRecordNeedsStrictlyHigherValue() {
        var s = Stats()
        XCTAssertTrue(s.raise(.total, to: 100, day: 20261116), "the first value sets the record")
        XCTAssertFalse(s.raise(.total, to: 100, day: 20261117), "equal does not break it")
        XCTAssertEqual(s.records[.total], RecordEntry(value: 100, day: 20261116), "and the day stays")
        XCTAssertFalse(s.raise(.total, to: 99, day: 20261117))
        XCTAssertTrue(s.raise(.total, to: 101, day: 20261118))
        XCTAssertEqual(s.records[.total], RecordEntry(value: 101, day: 20261118))
    }

    func testZeroIsNeverARecord() {
        var s = Stats()
        for id in RecordID.allCases { XCTAssertFalse(s.raise(id, to: 0, day: 20261116)) }
        XCTAssertTrue(s.records.isEmpty)
        XCTAssertEqual(s.value(.coins), nil)
    }

    func testRecordMilestoneListsMatchTheSpec() {
        XCTAssertEqual(RecordID.total.milestones, [100, 250, 500, 800, 1200])
        XCTAssertEqual(RecordID.stage.milestones, [30, 60, 100, 160, 250, 400])
        XCTAssertEqual(RecordID.pick.milestones, [10, 20, 40, 80, 150])
        XCTAssertEqual(RecordID.streak.milestones, [3, 5, 8, 12, 16, 20])
        XCTAssertEqual(RecordID.deep.milestones, [3, 6, 8, 10, 12, 15])
        XCTAssertEqual(RecordID.coins.milestones, [10, 20, 35, 50, 80])
    }

    // MARK: Milestone math

    func testProgressBeforeTheFirstMilestone() {
        let p = MilestoneProgress.of(50, in: RecordID.total.milestones)   // 0 -> 100
        XCTAssertEqual(p.achieved, 0)
        XCTAssertEqual(p.total, 5)
        XCTAssertEqual(p.next, 100)
        XCTAssertEqual(p.fraction, 0.5, accuracy: 1e-9)
        XCTAssertEqual(MilestoneProgress.of(0, in: [100]).fraction, 0)
    }

    func testProgressBetweenMilestonesUsesThePreviousOne() {
        // spec: (value - previous) / (next - previous); 3 of 5 reached at 500, next 800
        let p = MilestoneProgress.of(650, in: RecordID.total.milestones)
        XCTAssertEqual(p.achieved, 3)
        XCTAssertEqual(p.next, 800)
        XCTAssertEqual(p.fraction, (650.0 - 500) / (800 - 500), accuracy: 1e-9)
    }

    func testProgressExactlyOnAMilestoneStartsTheNextBar() {
        let p = MilestoneProgress.of(100, in: RecordID.total.milestones)
        XCTAssertEqual(p.achieved, 1)
        XCTAssertEqual(p.next, 250)
        XCTAssertEqual(p.fraction, 0, accuracy: 1e-9)
    }

    func testProgressPastTheLastMilestoneIsAllAchieved() {
        for v in [1200, 5000] {
            let p = MilestoneProgress.of(v, in: RecordID.total.milestones)
            XCTAssertEqual(p.achieved, 5)
            XCTAssertEqual(p.total, 5)
            XCTAssertNil(p.next, "全部達成")
            XCTAssertEqual(p.fraction, 1)
        }
    }

    func testStatsProgressUsesTheStoredRecord() {
        var s = Stats()
        XCTAssertEqual(s.progress(.streak).achieved, 0, "no record yet reads as 0")
        s.raise(.streak, to: 9, day: 1)
        let p = s.progress(.streak)           // 3, 5, 8 reached; next 12
        XCTAssertEqual(p.achieved, 3)
        XCTAssertEqual(p.next, 12)
        XCTAssertEqual(p.fraction, 1.0 / 4, accuracy: 1e-9)
        XCTAssertEqual(s.achievedTotal, 3)
    }

    // MARK: Counters (03 §4.1)

    func testCountPick() {
        var s = Stats()
        s.countPick(.safe(delta: 5))
        s.countPick(.boom(lost: 0, s0: 2, s1: 0))
        s.countPick(.shield)
        s.countPick(.defuse)
        XCTAssertEqual(s.picks, 4)
        XCTAssertEqual(s.safe, 1)
        XCTAssertEqual(s.booms, 1)
        XCTAssertEqual(s.shields, 2, "a shield and a defuse both count as stopped")
    }

    func testCountRunByModeAndLevel() {
        var s = Stats()
        s.countRun(mode: .free, lv: 2, won: true, allSuper: true, abandoned: false, blessings: [.add, .grit])
        s.countRun(mode: .free, lv: 2, won: false, allSuper: false, abandoned: true, blessings: [.grit])
        s.countRun(mode: .daily, lv: 0, won: true, allSuper: false, abandoned: false, blessings: [])
        XCTAssertEqual(s.runs, 3)
        XCTAssertEqual(s.abandons, 1)
        XCTAssertEqual(s.clears, 2)
        XCTAssertEqual(s.allSuper, 1)
        XCTAssertEqual(s.byLevel[2], Stats.Tally(runs: 2, clears: 1, best: 0))
        XCTAssertEqual(s.byLevel[0], Stats.Tally(), "the daily run does not touch byLevel")
        XCTAssertEqual(s.daily, Stats.Tally(runs: 1, clears: 1, best: 0))
        XCTAssertEqual(s.byBlessing[.grit], Stats.BlessingTally(runs: 2, wins: 1))
        XCTAssertEqual(s.byBlessing[.add], Stats.BlessingTally(runs: 1, wins: 1))
        XCTAssertNil(s.byBlessing[.snow])
    }

    func testBestKeepsTheHighestTotal() {
        var s = Stats()
        s.raiseBest(mode: .free, lv: 1, total: 300)
        s.raiseBest(mode: .free, lv: 1, total: 200)
        s.raiseBest(mode: .daily, lv: 0, total: 50)
        XCTAssertEqual(s.byLevel[1].best, 300)
        XCTAssertEqual(s.daily.best, 50)
    }

    // MARK: Codable

    func testStatsRoundTrip() throws {
        let sample = SampleData.make(today: 20261116).stats
        let back = try JSONDecoder().decode(Stats.self, from: JSONEncoder().encode(sample))
        XCTAssertEqual(back, sample)
    }

    func testSaveWithoutStatsDecodesToEmptyStats() throws {
        // A save written before Phase 6 has no "stats" key.
        let json = #"{"runs":{},"lastLevel":2,"unlock":3,"deepest":7,"muted":true,"onboardingDone":true,"daily":{"20261116":{"tries":2,"win":false}},"mode":"daily"}"#
        let save = try JSONDecoder().decode(SaveData.self, from: Data(json.utf8))
        XCTAssertEqual(save.stats, Stats())
        XCTAssertEqual(save.unlock, 3)
        XCTAssertEqual(save.daily[20261116]?.tries, 2, "the rest of the save is intact")
    }

    func testPartialOrBrokenStatsDecodeWithDefaults() throws {
        let partial = try JSONDecoder().decode(Stats.self, from: Data(#"{"runs":5,"records":{"total":{"value":120,"day":20261101}}}"#.utf8))
        XCTAssertEqual(partial.runs, 5)
        XCTAssertEqual(partial.value(.total), 120)
        XCTAssertEqual(partial.byLevel.count, Rules.difficulties.count)
        XCTAssertEqual(partial.daily, Stats.Tally())

        // A stats value that does not parse must not take the save down with it.
        let json = #"{"unlock":2,"stats":"garbage"}"#
        let save = try JSONDecoder().decode(SaveData.self, from: Data(json.utf8))
        XCTAssertEqual(save.unlock, 2)
        XCTAssertEqual(save.stats, Stats())
    }

    func testSaveRoundTripKeepsStats() throws {
        var save = SaveData()
        save.stats.countPick(.safe(delta: 3))
        save.stats.raise(.pick, to: 3, day: 20261116)
        save.stats.byBlessing[.grit] = Stats.BlessingTally(runs: 2, wins: 1)
        let back = try JSONDecoder().decode(SaveData.self, from: JSONEncoder().encode(save))
        XCTAssertEqual(back.stats, save.stats)
    }

    func testRunStateWithoutRecordBaseDecodes() throws {
        var run = GameEngine.newRun(seed: 5, lv: 0, mode: .free)
        run.brokenRecords = ["streak"]
        let data = try JSONEncoder().encode(run)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("recordBase"), "nil is not written")
        let back = try JSONDecoder().decode(RunState.self, from: data)
        XCTAssertNil(back.recordBase)
        XCTAssertEqual(back.brokenRecords, ["streak"])
    }

    func testOneBadFieldDoesNotWipeTheRest() throws {
        let json = #"""
        {"runs":"x","abandons":2,"picks":9,"byLevel":[{"runs":3,"clears":1,"best":50},"junk"],"daily":7,
         "records":{"total":{"value":120,"day":20261101},"bogus":{"value":1,"day":1},"pick":{"value":"bad"}},
         "byBlessing":{"grit":{"runs":2,"wins":1},"nope":{"runs":1,"wins":0},"add":"junk"}}
        """#
        let s = try JSONDecoder().decode(Stats.self, from: Data(json.utf8))
        XCTAssertEqual(s.runs, 0, "the wrong-typed counter falls back to 0")
        XCTAssertEqual(s.abandons, 2)
        XCTAssertEqual(s.picks, 9)
        XCTAssertEqual(s.byLevel.count, Rules.difficulties.count)
        XCTAssertEqual(s.byLevel[0], Stats.Tally(runs: 3, clears: 1, best: 50))
        XCTAssertEqual(s.byLevel[1], Stats.Tally(), "a bad entry is just empty")
        XCTAssertEqual(s.daily, Stats.Tally(), "wrong type")
        XCTAssertEqual(s.records, [.total: RecordEntry(value: 120, day: 20261101)], "unknown key and bad entry skipped")
        XCTAssertEqual(s.byBlessing, [.grit: Stats.BlessingTally(runs: 2, wins: 1)], "unknown id and bad entry skipped")
    }

    func testUnknownRecordKeyAloneKeepsEverythingElse() throws {
        let json = #"{"runs":4,"records":{"total":{"value":10,"day":1},"future":{"value":99,"day":1}}}"#
        let s = try JSONDecoder().decode(Stats.self, from: Data(json.utf8))
        XCTAssertEqual(s.runs, 4)
        XCTAssertEqual(s.records.count, 1)
    }

    // MARK: Sample data

    func testSampleDataIsRealisticAndSelfConsistent() {
        let today = 20261116
        let s = SampleData.make(today: today)
        XCTAssertEqual(s.stats.records.count, RecordID.allCases.count)
        XCTAssertLessThanOrEqual(s.stats.clears, s.stats.runs)
        XCTAssertEqual(s.stats.picks, s.stats.safe + s.stats.booms + 16, "301 = 201 safe + 84 boom + 16 saved")
        XCTAssertEqual(s.daily.count, 10)
        XCTAssertTrue(s.daily.keys.allSatisfy { $0 <= today && $0 > DayKey.adding(-14, to: today) }, "inside the 14-day calendar")
        for r in s.daily.values { XCTAssertEqual(r.hist.count, r.tries) }
        XCTAssertGreaterThan(DailyStats.clearedDays(s.daily), 0)
        XCTAssertLessThan(s.unlock, Rules.difficulties.count)
    }
}
