//
//  Phase6FollowUpTests.swift
//  BoomOrBonusTests
//
//  QA follow-ups: legacy order, difficulty change counts as an abandon, pills never leak into the next run,
//  and a pick is written once (stats and run together).
//

import XCTest
@testable import BoomOrBonus

private actor PillGate {
    private var waiting: [CheckedContinuation<Void, Never>] = []
    func wait() async { await withCheckedContinuation { waiting.append($0) } }
    func release() { let w = waiting; waiting = []; w.forEach { $0.resume() } }
}

@MainActor
final class Phase6FollowUpTests: XCTestCase {

    private let day = 20261116
    private let instant: GameViewModel.Sleeper = { _ in await Task.yield() }
    private var tempURLs: [URL] = []

    override func tearDown() {
        for u in tempURLs { try? FileManager.default.removeItem(at: u) }
        tempURLs = []
        super.tearDown()
    }

    private func makeVM(_ store: SaveStore, sleeper: GameViewModel.Sleeper? = nil, defaultMode: Mode = .free) -> GameViewModel {
        GameViewModel(store: store, sleeper: sleeper ?? instant, reduceMotion: { false }, feedbackEnabled: false,
                      randomSeed: { 777 }, today: { self.day }, defaultMode: defaultMode)
    }

    private func freeRun(stage: Int = 1, picks: Int? = nil, pair: [Card]? = nil,
                         blessings: [BlessingID: Int] = [:], lv: Int = 0) -> RunState {
        var r = GameEngine.newRun(seed: 4321, lv: lv, mode: .free)
        r.day = day
        r.stage = stage
        r.marks = Array(repeating: 1, count: stage - 1)
        r.shield = 0
        r.blessings = blessings
        r.stagePicksAtStart = GameEngine.stagePicks(r)
        r.picks = picks ?? r.stagePicksAtStart
        r.pair = pair ?? GameEngine.genPair(r)
        return r
    }

    private func store(free: RunState? = nil, daily: RunState? = nil, stats: Stats = Stats(),
                       unlock: Int = 3, mode: Mode? = nil, url: URL? = nil) -> SaveStore {
        let s = SaveStore(url: url)
        s.update { $0.runs.free = free; $0.runs.daily = daily; $0.stats = stats; $0.unlock = unlock; $0.mode = mode }
        return s
    }

    private func seasoned() -> Stats {
        var s = Stats()
        s.runs = 1
        for id in RecordID.allCases { s.raise(id, to: 1, day: 20261101) }
        return s
    }

    private func dailyRun() -> RunState {
        var d = GameEngine.newRun(seed: UInt32(day), lv: 0, mode: .daily, targetMul: Rules.DAILY_TM)
        d.day = day; d.attempt = 1
        d.stagePicksAtStart = GameEngine.stagePicks(d); d.picks = d.stagePicksAtStart
        d.pair = GameEngine.genPair(d)
        return d
    }

    private func pickSafe(_ vm: GameViewModel) async {
        guard let i = vm.run.pair.firstIndex(where: { !$0.boom }) else { return XCTFail("no safe card") }
        vm.pick(i)
        await vm.waitUntilSettled()
    }

    // MARK: Legacy list order (Major 1)

    func testLegacyRecordsShowNewestFirstWhateverTheDateFormat() {
        // The old writer appends each new day, with locale-formatted dates: text order would be wrong.
        let oldestFirst = ["2025年8月30日", "2025年9月5日", "2025年10月2日", "Sep 5, 2025"].enumerated().map {
            GameRecord(id: UUID(), date: $0.element, score: $0.offset, finalValue: 0, levelsPassed: 0, IntuitionLevel: "")
        }
        XCTAssertEqual(DailyRecordsView.newestFirst(oldestFirst).map(\.date),
                       ["Sep 5, 2025", "2025年10月2日", "2025年9月5日", "2025年8月30日"])
        XCTAssertEqual(oldestFirst.map(\.date).sorted(by: >).first, "Sep 5, 2025",
                       "a text sort would not have put 10月2日 first")
        XCTAssertTrue(DailyRecordsView.newestFirst([]).isEmpty)
    }

    // MARK: Difficulty change = abandon (Major 2)

    func testChangingDifficultyMidRunInFreePlayCountsAnAbandon() {
        let st = store(free: freeRun(stage: 2, blessings: [.grit: 1]))
        let vm = makeVM(st)
        vm.openDifficulty()
        XCTAssertEqual(vm.sheet, .difficulty)
        XCTAssertTrue(vm.difficultyReplacesRun)
        vm.startLevel(1)
        let s = st.data.stats
        XCTAssertEqual(s.runs, 1)
        XCTAssertEqual(s.abandons, 1)
        XCTAssertEqual(s.byLevel[0].runs, 1, "counted at the difficulty it was played on")
        XCTAssertEqual(s.byLevel[1].runs, 0)
        XCTAssertEqual(s.byBlessing[.grit], Stats.BlessingTally(runs: 1, wins: 0))
        XCTAssertEqual(vm.run.lv, 1, "and the new run is at the new level")
        XCTAssertFalse(vm.run.statsCounted)
        XCTAssertFalse(vm.run.abandoned)
    }

    func testChangingDifficultyBeforeTheFirstPickCountsNothing() {
        let st = store(free: freeRun())
        let vm = makeVM(st)
        vm.openDifficulty()
        vm.startLevel(1)
        XCTAssertEqual(st.data.stats.runs, 0)
        XCTAssertEqual(st.data.stats.abandons, 0)
    }

    func testPickingALevelFromAFinishedResultDoesNotCountTheRunTwice() async {
        let st = store(free: freeRun(picks: 1, pair: [boomCard(), boomCard()]))
        let vm = makeVM(st)
        vm.pick(0)
        await vm.waitUntilSettled()
        vm.endRun()
        XCTAssertEqual(st.data.stats.runs, 1)
        vm.startLevel(1)
        XCTAssertEqual(st.data.stats.runs, 1)
        XCTAssertEqual(st.data.stats.abandons, 0)
    }

    func testDailyChipPathReplacingTheWaitingFreeRunIsNotCounted() {
        let st = store(free: freeRun(stage: 3), daily: dailyRun(), mode: .daily)
        let vm = makeVM(st, defaultMode: .daily)
        XCTAssertEqual(vm.mode, .daily)
        XCTAssertTrue(vm.difficultyReplacesRun, "the warning shows")
        vm.openDifficulty()
        vm.startLevel(1)
        XCTAssertEqual(vm.mode, .free)
        XCTAssertEqual(vm.run.lv, 1)
        XCTAssertEqual(st.data.stats.runs, 0, "same as the prototype: only a warning, not an abandon")
        XCTAssertEqual(st.data.stats.abandons, 0)
        XCTAssertEqual(st.data.runs.daily?.attempt, 1, "the daily run is left as it is")
    }

    // MARK: Pills (Minor 3)

    func testPillsOfALeftRunDoNotShowOnTheNextOne() async {
        let gate = PillGate()
        let slow: GameViewModel.Sleeper = { s in
            if s == GameViewModel.pillSeconds { await gate.wait() } else { await Task.yield() }
        }
        let st = store(free: freeRun(pair: [safeCard(), safeCard()]), stats: seasoned())
        let vm = makeVM(st, sleeper: slow)
        for _ in 0..<2 { await pickSafe(vm) }
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNotNil(vm.recordPill)
        XCTAssertEqual(vm.pillLog.count, 2)

        vm.switchMode(.daily)                       // leaves the run
        XCTAssertNil(vm.recordPill)
        await gate.release()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(vm.recordPill, "the queued second pill is gone too")
    }

    func testAbandonStartsTheNextRunWithoutPills() async {
        let gate = PillGate()
        let slow: GameViewModel.Sleeper = { s in
            if s == GameViewModel.pillSeconds { await gate.wait() } else { await Task.yield() }
        }
        let st = store(free: freeRun(pair: [safeCard(), safeCard()]), stats: seasoned())
        let vm = makeVM(st, sleeper: slow)
        for _ in 0..<2 { await pickSafe(vm) }
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNotNil(vm.recordPill)
        vm.openRules()
        vm.abandon()
        XCTAssertNil(vm.recordPill)
        await gate.release()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(vm.recordPill)
        XCTAssertTrue(vm.run.brokenRecords.isEmpty, "a fresh run")
    }

    func testFinishAndWinningClearAreListedButNotPopped() async {
        var r = freeRun(stage: 6, picks: 2)
        r.total = 300
        r.coinsEarned = 12
        r.value = GameEngine.target(r)
        r.pair = GameEngine.genPair(r)
        let st = store(free: r, stats: seasoned())
        let vm = makeVM(st)
        vm.bank()
        await vm.waitUntilSettled()
        await vm.waitForPills()
        XCTAssertEqual(vm.run.phase, .win)
        XCTAssertEqual(Set(vm.run.brokenRecords), ["stage", "total", "deep", "coins"])
        XCTAssertTrue(vm.pillLog.isEmpty)
        XCTAssertNil(vm.recordPill)
        XCTAssertEqual(vm.brokenRecords.count, 4, "the result sheet lists them")
    }

    // MARK: One write per pick, brokenRecords persisted (Nits 6, 7)

    func testAPickIsWrittenOnceStatsAndRunTogether() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("save-\(UUID().uuidString).json")
        tempURLs.append(url)
        let st = store(free: freeRun(pair: [safeCard(), safeCard()]), url: url)
        let vm = makeVM(st)
        await pickSafe(vm)
        // Re-read the file as a relaunch would: the run and the counters cannot disagree.
        let disk = SaveStore(url: url).data
        XCTAssertEqual(disk.runs.free?.idx, 1)
        XCTAssertEqual(disk.stats.picks, 1)
        XCTAssertEqual(disk.stats.safe, 1)
        XCTAssertEqual(disk.runs.free?.recordBase, [])
    }

    func testBrokenRecordsArePersistedWithTheFinishedRun() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("save-\(UUID().uuidString).json")
        tempURLs.append(url)
        var r = freeRun(picks: 1, pair: [boomCard(), boomCard()])
        r.total = 500
        r.marks = [1, 1]; r.stage = 3
        let st = store(free: r, stats: seasoned(), url: url)
        let vm = makeVM(st)
        vm.pick(0)
        await vm.waitUntilSettled()
        vm.endRun()
        XCTAssertFalse(vm.run.brokenRecords.isEmpty)
        XCTAssertEqual(SaveStore(url: url).data.runs.free?.brokenRecords, vm.run.brokenRecords)
    }

    func testLegacyDebugHookIsParsedOnly() {
        XCTAssertTrue(DebugHooks.parse(arguments: ["-seed", "1", "-legacySample"]).legacySample)
        XCTAssertFalse(DebugHooks.parse(arguments: ["-seed", "1"]).legacySample)
    }
}
