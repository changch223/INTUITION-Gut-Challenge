//
//  GameViewModelStatsTests.swift
//  BoomOrBonusTests
//
//  Phase 6 in the view model: when each counter and record is updated (03 §4), abandons, the endless re-finish,
//  strict >, the new-record pill (never on the first run, once per record per run, queued) and brokenRecords.
//

import XCTest
@testable import BoomOrBonus

/// Holds the sleeps of exactly the length of a pill (and toast) until released, so a test can step through the queue.
private actor Gate {
    private var waiting: [CheckedContinuation<Void, Never>] = []
    func wait() async { await withCheckedContinuation { waiting.append($0) } }
    func release() {
        let w = waiting
        waiting = []
        w.forEach { $0.resume() }
    }
}

@MainActor
final class GameViewModelStatsTests: XCTestCase {

    private let day = 20261116
    private let instant: GameViewModel.Sleeper = { _ in await Task.yield() }

    private func makeVM(_ store: SaveStore, sleeper: GameViewModel.Sleeper? = nil, defaultMode: Mode = .free) -> GameViewModel {
        GameViewModel(store: store, sleeper: sleeper ?? instant, reduceMotion: { false }, feedbackEnabled: false,
                      randomSeed: { 777 }, today: { self.day }, defaultMode: defaultMode)
    }

    /// A free run at `stage`, stage picks full, no shield (so a bomb really explodes).
    private func freeRun(stage: Int = 1, picks: Int? = nil, value: Int = 0, pair: [Card]? = nil,
                         blessings: [BlessingID: Int] = [:], lv: Int = 0) -> RunState {
        var r = GameEngine.newRun(seed: 4321, lv: lv, mode: .free)
        r.day = day
        r.stage = stage
        r.marks = Array(repeating: 1, count: stage - 1)
        r.shield = 0
        r.blessings = blessings
        r.stagePicksAtStart = GameEngine.stagePicks(r)
        r.picks = picks ?? r.stagePicksAtStart
        r.value = value
        r.pair = pair ?? GameEngine.genPair(r)
        return r
    }

    private func store(free: RunState? = nil, daily: RunState? = nil, stats: Stats = Stats(), mode: Mode? = nil) -> SaveStore {
        let s = SaveStore(url: nil)
        s.update {
            $0.runs.free = free
            $0.runs.daily = daily
            $0.stats = stats
            $0.mode = mode
        }
        return s
    }

    /// Stats that look like one finished earlier run, so every record already exists (value 1 each unless given).
    private func seasoned(_ values: [RecordID: Int] = [:]) -> Stats {
        var s = Stats()
        s.runs = 1
        for id in RecordID.allCases { s.raise(id, to: values[id] ?? 1, day: 20261101) }
        return s
    }

    private func pickSafe(_ vm: GameViewModel) async {
        guard let i = vm.run.pair.firstIndex(where: { !$0.boom }) else { return XCTFail("no safe card in this pair") }
        vm.pick(i)
        await vm.waitUntilSettled()
    }

    private func pickBoom(_ vm: GameViewModel) async {
        guard let i = vm.run.pair.firstIndex(where: { $0.boom }) else { return XCTFail("no bomb in this pair") }
        vm.pick(i)
        await vm.waitUntilSettled()
    }

    // MARK: - Counters per reveal

    func testPicksSafeBoomsCountAtReveal() async {
        let st = store(free: freeRun(pair: [safeCard(), boomCard()]))
        let vm = makeVM(st)
        XCTAssertEqual(st.data.stats.picks, 0)
        await pickSafe(vm)
        XCTAssertEqual(st.data.stats.picks, 1)
        XCTAssertEqual(st.data.stats.safe, 1)
        XCTAssertEqual(st.data.stats.booms, 0)

        // The next pair is dealt by the engine; force the bomb case with a stored pair instead.
        let st2 = store(free: freeRun(pair: [boomCard(), boomCard(3)]))
        let vm2 = makeVM(st2)
        vm2.pick(0)
        await vm2.waitUntilSettled()
        XCTAssertEqual(st2.data.stats.picks, 1)
        XCTAssertEqual(st2.data.stats.booms, 1)
        XCTAssertEqual(st2.data.stats.safe, 0)
        XCTAssertEqual(st2.data.stats.shields, 0)
    }

    func testShieldAndDefuseCountAsStopped() async {
        var r = freeRun(pair: [boomCard(), boomCard()])
        r.shield = 1
        let st = store(free: r)
        let vm = makeVM(st)
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(st.data.stats.shields, 1)
        XCTAssertEqual(st.data.stats.picks, 1, "a stopped bomb is still a reveal")
        XCTAssertEqual(st.data.stats.booms, 0)

        let st2 = store(free: freeRun(pair: [boomCard(), boomCard()], blessings: [.defuse: 1]))
        let vm2 = makeVM(st2)
        vm2.pick(0)
        await vm2.waitUntilSettled()
        XCTAssertEqual(st2.data.stats.shields, 1)
        XCTAssertEqual(st2.data.stats.booms, 0)
    }

    func testRunCountersAreNotTouchedByPicks() async {
        let st = store(free: freeRun(pair: [safeCard(), boomCard()]))
        let vm = makeVM(st)
        await pickSafe(vm)
        XCTAssertEqual(st.data.stats.runs, 0, "runs counts at the end of a run")
        XCTAssertFalse(vm.run.statsCounted)
    }

    // MARK: - Finish

    /// One pick left, a bomb to take it, target not reached: the fail panel, then 「結束這局」.
    private func failedRun(blessings: [BlessingID: Int] = [:], lv: Int = 0) async -> (GameViewModel, SaveStore) {
        let st = store(free: freeRun(picks: 1, pair: [boomCard(), boomCard()], blessings: blessings, lv: lv))
        let vm = makeVM(st)
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .fail)
        XCTAssertEqual(st.data.stats.runs, 0, "the fail panel can still be answered with an ad")
        vm.endRun()
        return (vm, st)
    }

    func testFinishCountsTheRunOnceWithItsLevelAndBlessings() async {
        let (vm, st) = await failedRun(blessings: [.grit: 2, .add: 1], lv: 1)
        let s = st.data.stats
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(s.runs, 1)
        XCTAssertEqual(s.abandons, 0)
        XCTAssertEqual(s.clears, 0)
        XCTAssertEqual(s.allSuper, 0)
        XCTAssertEqual(s.byLevel[1].runs, 1)
        XCTAssertEqual(s.byLevel[1].clears, 0)
        XCTAssertEqual(s.byLevel[0].runs, 0)
        XCTAssertEqual(s.daily.runs, 0)
        XCTAssertEqual(s.byBlessing[.grit], Stats.BlessingTally(runs: 1, wins: 0), "an owned blessing counts once, whatever its stack")
        XCTAssertEqual(s.byBlessing[.add], Stats.BlessingTally(runs: 1, wins: 0))
        XCTAssertEqual(s.byBlessing.count, 2)
        XCTAssertTrue(vm.run.statsCounted)
    }

    func testFinishIsNotCountedTwiceForTheSameRun() async {
        let (vm, st) = await failedRun()
        vm.endRun()                    // the sheet is gone from the state machine: ignored
        vm.closeRules()
        XCTAssertEqual(st.data.stats.runs, 1)
    }

    func testRecordsAtFinishAreTotalDeepAndCoins() async {
        var r = freeRun(picks: 1, value: 40, pair: [boomCard(), boomCard()])
        r.total = 200
        r.coinsEarned = 17
        r.marks = [1, 1, 1]
        r.stage = 4
        let st = store(free: r)
        let vm = makeVM(st)
        vm.pick(0)
        await vm.waitUntilSettled()
        vm.endRun()
        let s = st.data.stats
        XCTAssertEqual(s.value(.total), vm.run.total)
        XCTAssertGreaterThanOrEqual(vm.run.total, 200)
        XCTAssertEqual(s.value(.deep), 3, "stages cleared; the failed one does not count")
        XCTAssertEqual(s.value(.coins), 17, "stage-clear rewards only")
        XCTAssertEqual(s.byLevel[0].best, vm.run.total)
        XCTAssertEqual(s.records[.total]?.day, day)
    }

    func testAbandonCountsAsARunAndAnAbandon() async {
        // Free play: only a run that has started counts.
        let st = store(free: freeRun(stage: 2))
        let vm = makeVM(st)
        vm.openRules()
        vm.abandon()
        XCTAssertEqual(st.data.stats.runs, 1)
        XCTAssertEqual(st.data.stats.abandons, 1)
        XCTAssertEqual(st.data.stats.byLevel[0].runs, 1)

        let fresh = store(free: freeRun())
        let vm2 = makeVM(fresh)
        vm2.openRules()
        vm2.abandon()
        XCTAssertEqual(fresh.data.stats.runs, 0, "an untouched free run is just replaced")
        XCTAssertEqual(fresh.data.stats.abandons, 0)
    }

    func testDailyAbandonCountsEvenBeforeTheFirstPick() async {
        var d = GameEngine.newRun(seed: UInt32(day), lv: 0, mode: .daily, targetMul: Rules.DAILY_TM)
        d.day = day; d.attempt = 1
        d.stagePicksAtStart = GameEngine.stagePicks(d); d.picks = d.stagePicksAtStart
        d.pair = GameEngine.genPair(d)
        let st = store(daily: d, mode: .daily)
        let vm = makeVM(st, defaultMode: .daily)
        XCTAssertEqual(vm.mode, .daily)
        vm.openRules()
        vm.abandon()
        let s = st.data.stats
        XCTAssertEqual(s.runs, 1)
        XCTAssertEqual(s.abandons, 1)
        XCTAssertEqual(s.daily.runs, 1)
        XCTAssertEqual(s.byLevel.map(\.runs).reduce(0, +), 0, "the daily challenge has its own tally")
        XCTAssertEqual(st.data.daily[day]?.tries, 1, "and the DailyRecord still counts the attempt")
        XCTAssertEqual(vm.run.attempt, 2, "the next attempt started with fresh flags")
        XCTAssertFalse(vm.run.statsCounted)
    }

    // MARK: - Stage clear and win

    /// Stage 6, the target reached, one pick left to spend: banking wins the run.
    private func winnable(coinsEarned: Int = 12) -> RunState {
        var r = freeRun(stage: 6, picks: 2)
        r.total = 300
        r.coinsEarned = coinsEarned
        r.value = GameEngine.target(r)
        r.pair = GameEngine.genPair(r)
        return r
    }

    func testStageRecordIsCheckedAtEveryClearWithTheStageScore() async {
        var r = freeRun(stage: 2, picks: 2)
        r.value = GameEngine.target(r) + 7
        let st = store(free: r, stats: seasoned([.stage: 5]))
        let vm = makeVM(st)
        let score = vm.run.value
        vm.bank()
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.run.phase, .shop)
        XCTAssertEqual(st.data.stats.value(.stage), score)
        XCTAssertEqual(vm.run.brokenRecords, ["stage"])
        XCTAssertEqual(st.data.stats.runs, 1 as Int, "unchanged: a clear is not the end of the run")
    }

    func testWinCountsClearAndLaterEndlessRefinishDoesNotCountAgain() async {
        let st = store(free: winnable())
        let vm = makeVM(st)
        vm.bank()
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.run.phase, .win)
        var s = st.data.stats
        XCTAssertEqual(s.runs, 1)
        XCTAssertEqual(s.clears, 1)
        XCTAssertEqual(s.byLevel[0], Stats.Tally(runs: 1, clears: 1, best: vm.run.total))
        XCTAssertEqual(s.value(.deep), 6)
        XCTAssertEqual(s.value(.total), vm.run.total)
        XCTAssertEqual(s.value(.coins), vm.run.coinsEarned)
        XCTAssertGreaterThan(vm.run.coinsEarned, 12, "this clear's reward is added to the 12 before it")
        let totalAtWin = vm.run.total

        // Endless: through the shop to stage 7, bank a safe pick or two, then give up.
        vm.startEndless()
        vm.nextStage()
        XCTAssertEqual(vm.run.stage, 7)
        await pickSafe(vm)
        vm.openRules()
        vm.abandon()
        await vm.waitForPills()

        s = st.data.stats
        XCTAssertEqual(s.runs, 1, "the endless re-finish does not count the run again")
        XCTAssertEqual(s.clears, 1)
        XCTAssertEqual(s.abandons, 0, "it was counted before it was abandoned")
        XCTAssertEqual(s.byLevel[0].runs, 1)
        XCTAssertEqual(s.byLevel[0].clears, 1)
        XCTAssertGreaterThan(s.value(.total) ?? 0, totalAtWin, "but total is refreshed")
        XCTAssertEqual(s.byLevel[0].best, s.value(.total))
    }

    func testEndlessRefinishRaisesDeepAndCoinsToo() async {
        // Run counted at the win (flags as the win left them), now in endless stage 8 after clearing stage 7.
        var r = freeRun(stage: 8, picks: 1, pair: [boomCard(), boomCard()])
        r.endless = true
        r.marks = Array(repeating: 1, count: 7)
        r.total = 900
        r.coinsEarned = 44
        r.statsCounted = true
        let st = store(free: r, stats: seasoned([.deep: 6, .coins: 30, .total: 700]))
        var base = st.data.stats
        base.runs = 1; base.clears = 1
        st.update { $0.stats = base }
        let vm = makeVM(st)
        vm.pick(0)
        await vm.waitUntilSettled()
        vm.endRun()
        let s = st.data.stats
        XCTAssertEqual(s.runs, 1)
        XCTAssertEqual(s.clears, 1)
        XCTAssertEqual(s.value(.deep), 7)
        XCTAssertEqual(s.value(.coins), 44)
        XCTAssertEqual(s.value(.total), vm.run.total)
        XCTAssertEqual(Set(vm.run.brokenRecords), ["deep", "coins", "total"])
    }

    func testByBlessingWinsOnlyForAClearingRun() async {
        var r = winnable()
        r.blessings = [.snow: 3, .eye: 1]
        let st = store(free: r)
        let vm = makeVM(st)
        vm.bank()
        await vm.waitUntilSettled()
        XCTAssertEqual(st.data.stats.byBlessing[.snow], Stats.BlessingTally(runs: 1, wins: 1))
        XCTAssertEqual(st.data.stats.byBlessing[.eye], Stats.BlessingTally(runs: 1, wins: 1))
    }

    func testAllSuperCountsWhenTheFirstSixAreStretchClears() async {
        var r = freeRun(stage: 6, picks: 2)
        r.marks = Array(repeating: 2, count: 5)
        r.total = 300
        r.value = GameEngine.stretch(r)
        r.pair = GameEngine.genPair(r)
        let st = store(free: r)
        let vm = makeVM(st)
        vm.bank()
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.run.marks, Array(repeating: 2, count: 6))
        XCTAssertEqual(st.data.stats.allSuper, 1)
        XCTAssertEqual(st.data.stats.clears, 1)
    }

    func testDailyRunUsesTheDailyTally() async {
        var d = GameEngine.newRun(seed: UInt32(day), lv: 0, mode: .daily, targetMul: Rules.DAILY_TM)
        d.day = day; d.attempt = 1; d.stage = 6
        d.marks = Array(repeating: 1, count: 5)
        d.total = 300
        d.stagePicksAtStart = GameEngine.stagePicks(d); d.picks = 2
        d.value = GameEngine.target(d)
        d.pair = GameEngine.genPair(d)
        let st = store(daily: d, mode: .daily)
        let vm = makeVM(st, defaultMode: .daily)
        vm.bank()
        await vm.waitUntilSettled()
        XCTAssertEqual(st.data.stats.daily, Stats.Tally(runs: 1, clears: 1, best: vm.run.total))
        XCTAssertEqual(st.data.stats.byLevel.map(\.runs).reduce(0, +), 0)
        XCTAssertEqual(st.data.daily[day]?.win, true)
    }

    // MARK: - Records and the pill

    func testFirstRunNeverPopsARecordEvenThoughItSetsThem() async {
        let st = store(free: freeRun(pair: [safeCard(), safeCard(n: 7)]))
        let vm = makeVM(st)
        await pickSafe(vm)
        await pickSafe(vm)
        await pickSafe(vm)
        XCTAssertGreaterThanOrEqual(vm.run.streak, 2)
        XCTAssertEqual(st.data.stats.value(.streak), vm.run.streak, "the records were set")
        XCTAssertGreaterThan(st.data.stats.value(.pick) ?? 0, 0)
        XCTAssertTrue(vm.pillLog.isEmpty, "but there was no earlier record to break")
        XCTAssertTrue(vm.run.brokenRecords.isEmpty)
        XCTAssertNil(vm.recordPill)
        XCTAssertNil(vm.run.recordBase?.first, "an empty base: nothing existed before this run")
    }

    func testRecordBaseIsTakenBeforeTheRunChangesAnything() async {
        let st = store(free: freeRun(pair: [safeCard(), safeCard()]), )
        let vm = makeVM(st)
        XCTAssertNil(vm.run.recordBase, "nothing checked yet")
        await pickSafe(vm)
        XCTAssertEqual(vm.run.recordBase, [])
    }

    func testEachRecordPopsAtMostOncePerRun() async {
        let st = store(free: freeRun(pair: [safeCard(), safeCard()]), stats: seasoned())
        let vm = makeVM(st)
        for _ in 0..<3 { await pickSafe(vm) }
        await vm.waitForPills()
        let names = vm.pillLog.map(\.record)
        XCTAssertEqual(names.count, Set(names).count, "no record twice in one run")
        XCTAssertEqual(Set(names), [.pick, .streak])
        XCTAssertEqual(vm.run.brokenRecords.sorted(), ["pick", "streak"])
        // The streak is already 3 by now: a fourth safe pick raises both again, silently.
        let before = vm.pillLog.count
        await pickSafe(vm)
        XCTAssertEqual(vm.pillLog.count, before)
        XCTAssertGreaterThan(st.data.stats.value(.streak) ?? 0, 2)
    }

    func testEqualToTheRecordIsNotABreak() async {
        // The first pick is worth exactly 5 (streak 0); the old pick record is 5, the old streak record is far away.
        let st = store(free: freeRun(pair: [safeCard(n: 5), safeCard(n: 5)]), stats: seasoned([.pick: 5, .streak: 50]))
        let vm = makeVM(st)
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.run.idx, 1)
        XCTAssertEqual(vm.run.value, 5)
        XCTAssertEqual(st.data.stats.records[.pick], RecordEntry(value: 5, day: 20261101), "untouched, same day too")
        XCTAssertTrue(vm.pillLog.isEmpty, "equal is not strictly greater")
        XCTAssertTrue(vm.run.brokenRecords.isEmpty)
    }

    func testPillTextAndOrderAreQueuedWithoutOverlap() async {
        let gate = Gate()
        let slow: GameViewModel.Sleeper = { s in
            if s == GameViewModel.pillSeconds { await gate.wait() } else { await Task.yield() }
        }
        let st = store(free: freeRun(pair: [safeCard(), safeCard()]), stats: seasoned())
        let vm = makeVM(st, sleeper: slow)
        for _ in 0..<2 { await pickSafe(vm) }        // pick record on the first pick, streak on the second
        XCTAssertEqual(vm.pillLog.map(\.record), [.pick, .streak])
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(vm.recordPill?.record, .pick, "the second waits for the first")
        XCTAssertEqual(vm.recordPill?.text, "★ 新紀錄　單手最高得分 " + Fmt.int(vm.pillLog[0].value))
        await gate.release()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(vm.recordPill?.record, .streak)
        await gate.release()
        await vm.waitForPills()
        XCTAssertNil(vm.recordPill, "gone after its 2.4 s")
    }

    func testPillStaysTwoPointFourSeconds() {
        XCTAssertEqual(GameViewModel.pillSeconds, 2.4)
    }

    func testBrokenRecordsListsTheRecordsWithTheirFinalValues() async {
        var r = freeRun(picks: 1, value: 60, pair: [boomCard(), boomCard()])
        r.total = 500
        r.coinsEarned = 25
        r.marks = Array(repeating: 1, count: 3); r.stage = 4
        let st = store(free: r, stats: seasoned([.total: 100, .deep: 2, .coins: 10, .pick: 999, .streak: 999, .stage: 999]))
        let vm = makeVM(st)
        vm.pick(0)
        await vm.waitUntilSettled()
        vm.endRun()
        XCTAssertEqual(vm.run.brokenRecords, ["total", "deep", "coins"], "finish order")
        XCTAssertEqual(vm.brokenRecords.map(\.id), [.total, .deep, .coins])
        XCTAssertEqual(vm.brokenRecords.map(\.value), [vm.run.total, 3, 25])
        await vm.waitForPills()
        XCTAssertTrue(vm.pillLog.isEmpty, "finish-time records are listed on the result sheet, not popped behind it")
    }

    func testAnUnbrokenRecordIsNotListed() async {
        var r = freeRun(picks: 1, value: 0, pair: [boomCard(), boomCard()])
        r.total = 10
        let st = store(free: r, stats: seasoned([.total: 5000, .deep: 9, .coins: 90]))
        let vm = makeVM(st)
        vm.pick(0)
        await vm.waitUntilSettled()
        vm.endRun()
        XCTAssertTrue(vm.run.brokenRecords.isEmpty)
        XCTAssertTrue(vm.brokenRecords.isEmpty)
        XCTAssertEqual(st.data.stats.value(.total), 5000)
    }

    func testRecordSetForTheFirstTimeInThisRunDoesNotPop() async {
        // The player has a history, but never cleared a stage: 單關最高分 does not exist before this run.
        var r = freeRun(stage: 1, picks: 2)
        r.value = GameEngine.target(r) + 3
        var old = seasoned()
        old.records[.stage] = nil
        let st = store(free: r, stats: old)
        let vm = makeVM(st)
        vm.bank()
        await vm.waitUntilSettled()
        XCTAssertEqual(st.data.stats.value(.stage), r.value, "the record is set")
        XCTAssertEqual(vm.run.recordBase?.contains("stage"), false)
        XCTAssertTrue(vm.pillLog.isEmpty)
        XCTAssertTrue(vm.run.brokenRecords.isEmpty)
    }

    // MARK: - Dashboard state

    func testHasRecordsAndOpenDashboard() async {
        let st = store(free: freeRun())
        let vm = makeVM(st)
        XCTAssertFalse(vm.hasRecords)
        vm.openDashboard()
        XCTAssertEqual(vm.sheet, .dashboard)
        vm.closeDashboard()
        XCTAssertNil(vm.sheet)
        vm.openRules()
        vm.openDashboard()
        XCTAssertEqual(vm.sheet, .dashboard, "from the rules panel footer")
        vm.closeDashboard()

        let (vm2, _) = await failedRun()
        XCTAssertTrue(vm2.hasRecords)
        vm2.openDashboard()
        XCTAssertEqual(vm2.sheet, .result, "not over another sheet")
    }

    func testDashboardIsBlockedWhileAPickResolves() {
        let vm = makeVM(store(free: freeRun()))
        vm.pick(0)
        vm.openDashboard()
        XCTAssertNil(vm.sheet)
    }

    func testStatsSeedHooksFillTheSave() {
        let st = SaveStore(url: nil)
        var hooks = DebugHooks()
        hooks.stats = .sample
        _ = GameViewModel(store: st, launchSeed: 5, hooks: hooks, sleeper: instant, reduceMotion: { false },
                          feedbackEnabled: false, today: { 20261116 })
        XCTAssertGreaterThan(st.data.stats.runs, 0)
        XCTAssertEqual(st.data.daily.count, 10)
        XCTAssertEqual(DebugHooks.parse(arguments: ["-seed", "1", "-stats", "low"]).stats, .low)
        XCTAssertNil(DebugHooks.parse(arguments: ["-seed", "1", "-stats", "nope"]).stats)
    }
}

private extension Stats {
    func with(_ change: (inout Stats) -> Void) -> Stats {
        var s = self
        change(&s)
        return s
    }
}
