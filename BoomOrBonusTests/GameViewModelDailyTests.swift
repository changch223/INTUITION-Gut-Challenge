//
//  GameViewModelDailyTests.swift
//  BoomOrBonusTests
//
//  Phase 4: daily mode in the view model: seed and attempt, attempts counted, winTry, endless re-finish,
//  midnight, mode switching, abandon, copy and the ? panel. The date comes from an injected provider.
//

import XCTest
import UIKit
@testable import BoomOrBonus

@MainActor
final class GameViewModelDailyTests: XCTestCase {

    private final class Day { var value: Int; init(_ v: Int) { value = v } }

    private let d1 = 20261116
    private let d2 = 20261117
    private let instant: GameViewModel.Sleeper = { _ in await Task.yield() }

    private var tempURLs: [URL] = []

    override func tearDown() {
        for u in tempURLs { try? FileManager.default.removeItem(at: u) }
        tempURLs = []
        super.tearDown()
    }

    private func tempURL() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("save-\(UUID().uuidString).json")
        tempURLs.append(u)
        return u
    }

    /// `seed` nil = launch like the app (mode from the save, `defaultMode` for a new install).
    private func makeVM(store: SaveStore = SaveStore(url: nil), day: Day, seed: UInt32? = nil,
                        hooks: DebugHooks = DebugHooks(), defaultMode: Mode = .daily) -> GameViewModel {
        GameViewModel(store: store, launchSeed: seed, hooks: hooks, sleeper: instant,
                      reduceMotion: { false }, feedbackEnabled: false, randomSeed: { 777 },
                      today: { day.value }, defaultMode: defaultMode)
    }

    private func dailyRun(day: Int, attempt: Int = 1, stage: Int = 1) -> RunState {
        var r = GameEngine.newRun(seed: UInt32(day), lv: 0, mode: .daily, targetMul: Rules.DAILY_TM)
        r.day = day
        r.attempt = attempt
        r.stage = stage
        r.marks = Array(repeating: 1, count: stage - 1)
        r.picks = GameEngine.stagePicks(r)
        r.stagePicksAtStart = r.picks
        r.pair = GameEngine.genPair(r)
        return r
    }

    /// One tap away from banking the sixth stage.
    private func winnable(day: Int, attempt: Int) -> RunState {
        var r = dailyRun(day: day, attempt: attempt, stage: 6)
        r.total = 300
        r.value = GameEngine.target(r)
        r.picks -= 1
        r.pair = GameEngine.genPair(r)
        return r
    }

    private func store(daily run: RunState? = nil, free: RunState? = nil, mode: Mode? = nil,
                       records: [Int: DailyRecord] = [:], url: URL? = nil) -> SaveStore {
        let s = SaveStore(url: url)
        s.update {
            $0.runs.daily = run
            $0.runs.free = free
            $0.mode = mode
            $0.daily = records
        }
        return s
    }

    private func pickCard0(_ vm: GameViewModel) async {
        vm.pick(0)
        await vm.waitUntilSettled()
    }

    // MARK: - Starting a daily run (03 §2.2)

    func testDailyRunUsesTodaysSeedLevelZeroAndTargetTimesOnePointThree() {
        let vm = makeVM(day: Day(d1))
        XCTAssertEqual(vm.mode, .daily, "a new install opens on the daily challenge")
        XCTAssertEqual(vm.run.seed, UInt32(d1))
        XCTAssertEqual(vm.run.lv, 0)
        XCTAssertEqual(vm.run.targetMul, 1.3)
        XCTAssertEqual(vm.run.attempt, 1)
        XCTAssertEqual(vm.run.day, d1)
        XCTAssertEqual(vm.target, 23, "stage 1 target 18 x 1.3")
    }

    func testAttemptIsTriesPlusOne() {
        var rec = DailyRecord(); rec.tries = 4
        let vm = makeVM(store: store(mode: .daily, records: [d1: rec]), day: Day(d1))
        XCTAssertEqual(vm.run.attempt, 5)
        // Another day is unaffected.
        let other = makeVM(store: store(mode: .daily, records: [d1: rec]), day: Day(d2))
        XCTAssertEqual(other.run.attempt, 1)
    }

    func testTwoDevicesOnTheSameDayDealTheSameFirstFivePairs() async {
        func firstFivePairs(_ vm: GameViewModel) async -> [[Card]] {
            var pairs = [vm.run.pair]
            for _ in 0..<4 {
                await pickCard0(vm)
                pairs.append(vm.run.pair)
            }
            return pairs
        }
        let a = makeVM(day: Day(d1))
        let b = GameViewModel(store: SaveStore(url: nil), launchSeed: nil, sleeper: instant, reduceMotion: { false },
                              feedbackEnabled: false, randomSeed: { 424242 }, today: { self.d1 }, defaultMode: .daily)
        let pa = await firstFivePairs(a)
        let pb = await firstFivePairs(b)
        XCTAssertEqual(pa.count, 5)
        XCTAssertEqual(pa, pb)
        // A different day is a different deck.
        let c = makeVM(day: Day(d2))
        XCTAssertNotEqual(c.run.pair, pa[0])
    }

    func testDailyResumesAfterRelaunchOnTheSameDay() async {
        let url = tempURL()
        let day = Day(d1)
        let vm = makeVM(store: SaveStore(url: url), day: day)
        await pickCard0(vm)
        let run = vm.run
        XCTAssertEqual(run.idx, 1)
        let again = makeVM(store: SaveStore(url: url), day: day)          // relaunch
        XCTAssertEqual(again.mode, .daily)
        XCTAssertEqual(again.run, run)
    }

    // MARK: - Attempts (03 §3.1)

    func testAbandoningCountsOneTryEvenWithZeroPicks() {
        let s = SaveStore(url: nil)
        let vm = makeVM(store: s, day: Day(d1))
        XCTAssertEqual(vm.run.attempt, 1)
        vm.abandon()
        let rec = s.data.daily[d1]
        XCTAssertEqual(rec?.tries, 1)
        XCTAssertEqual(rec?.hist, [DailyRecord.Attempt(cleared: 0, total: 0)])
        XCTAssertEqual(rec?.win, false)
        XCTAssertEqual(vm.run.attempt, 2, "the next attempt starts right away")
        XCTAssertEqual(vm.run.picks, vm.run.stagePicksAtStart)
        XCTAssertFalse(vm.run.dailyCounted)
        XCTAssertFalse(vm.run.abandoned)
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.seed, UInt32(d1), "same deck again")
        vm.abandon()
        XCTAssertEqual(s.data.daily[d1]?.tries, 2)
        XCTAssertEqual(vm.run.attempt, 3)
        XCTAssertEqual(s.data.daily[d1]?.hist.count, 2)
    }

    func testAbandonedRunIsFlaggedAndKeepsItsTotal() async {
        let s = SaveStore(url: nil)
        let vm = makeVM(store: s, day: Day(d1))
        await pickCard0(vm)
        let scoreBefore = vm.run.value
        vm.abandon()
        XCTAssertEqual(s.data.daily[d1]?.hist.last?.total, scoreBefore)
        XCTAssertEqual(s.data.daily[d1]?.marks, [0])
    }

    func testOutOfPicksFailureCountsAndShowsTheResult() async {
        // Stage 1, one pick left, far below the target; the ad was already used.
        var r = dailyRun(day: d1, attempt: 2)
        r.picks = 1
        r.adUsed = true
        r.value = 0
        let s = store(daily: r, mode: .daily)
        let vm = makeVM(store: s, day: Day(d1))
        await pickCard0(vm)
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(vm.run.phase, .over)
        XCTAssertEqual(s.data.daily[d1]?.tries, 2)
        XCTAssertEqual(s.data.daily[d1]?.hist.count, 1)
        XCTAssertTrue(vm.run.dailyCounted)
        XCTAssertEqual(vm.nextDailyAttempt, 3)
        XCTAssertTrue(s.data.runs.daily?.dailyCounted == true, "run and record are written together")
    }

    func testFailSheetThenEndRunCountsOnce() async {
        var r = dailyRun(day: d1)
        r.picks = 1
        let s = store(daily: r, mode: .daily)
        let vm = makeVM(store: s, day: Day(d1))
        await pickCard0(vm)
        XCTAssertEqual(vm.sheet, .fail)
        XCTAssertNil(s.data.daily[d1], "not an attempt until the run really ends")
        vm.endRun()
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(s.data.daily[d1]?.tries, 1)
    }

    func testClearRecordsWinTryAndTheRepresentativeTotal() async {
        var before = DailyRecord(); before.tries = 2; before.total = 999; before.marks = [1, 0]
        before.hist = [.init(cleared: 1, total: 999), .init(cleared: 0, total: 0)]
        let s = store(daily: winnable(day: d1, attempt: 3), mode: .daily, records: [d1: before])
        let vm = makeVM(store: s, day: Day(d1))
        vm.bank()
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.run.phase, .win)
        XCTAssertEqual(vm.sheet, .result)
        let rec = s.data.daily[d1]!
        XCTAssertTrue(rec.win)
        XCTAssertEqual(rec.winTry, 3)
        XCTAssertEqual(rec.tries, 3)
        XCTAssertEqual(rec.hist.count, 3)
        XCTAssertEqual(rec.total, vm.run.total, "after a clear the clearing run is the representative one (999 before)")
        XCTAssertEqual(rec.marks.count, 6)
        XCTAssertEqual(s.data.unlock, 1, "a daily clear counts as clearing level 0")
    }

    func testEndlessFinishAfterAClearDoesNotAddATry() async {
        var rec = DailyRecord()
        rec.tries = 3; rec.win = true; rec.winTry = 3; rec.total = 300
        rec.marks = [1, 1, 1, 1, 1, 1]
        rec.hist = [.init(cleared: 6, total: 300)]
        // Endless stage 7, one pick left, the clear already counted.
        var r = dailyRun(day: d1, attempt: 3, stage: 7)
        r.marks = [1, 1, 1, 1, 1, 1]
        r.endless = true
        r.dailyCounted = true
        r.adUsed = true
        r.total = 300
        r.value = 50
        r.picks = 1
        r.pair = GameEngine.genPair(r)
        let s = store(daily: r, mode: .daily, records: [d1: rec])
        let vm = makeVM(store: s, day: Day(d1))
        await pickCard0(vm)
        XCTAssertEqual(vm.sheet, .result)
        let after = s.data.daily[d1]!
        XCTAssertEqual(after.tries, 3)
        XCTAssertEqual(after.hist.count, 1)
        XCTAssertEqual(after.winTry, 3)
        XCTAssertEqual(after.total, vm.run.total, "the endless total is higher, so it takes over")
        XCTAssertGreaterThan(after.total, 300)
        XCTAssertEqual(after.marks.count, 7)
    }

    // MARK: - Midnight (03 §2.1)

    func testMidnightRolloverDiscardsYesterdaysRunWithoutCountingIt() async {
        let s = SaveStore(url: nil)
        let day = Day(d1)
        let vm = makeVM(store: s, day: day)
        await pickCard0(vm)
        XCTAssertNil(s.data.daily[d1])
        day.value = d2
        vm.refreshDay()
        XCTAssertEqual(vm.run.day, d2)
        XCTAssertEqual(vm.run.seed, UInt32(d2))
        XCTAssertEqual(vm.run.attempt, 1)
        XCTAssertEqual(vm.run.idx, 0)
        XCTAssertNil(s.data.daily[d1], "not an attempt")
        XCTAssertNil(s.data.daily[d2])
        XCTAssertEqual(s.data.runs.daily?.day, d2)
    }

    func testAbandonAfterMidnightDoesNotCountAgainstYesterday() async {
        let s = SaveStore(url: nil)
        let day = Day(d1)
        let vm = makeVM(store: s, day: day)
        await pickCard0(vm)
        day.value = d2                                     // midnight passes, no foreground event
        vm.abandon()
        XCTAssertNil(s.data.daily[d1], "yesterday's tries stay 0")
        XCTAssertNil(s.data.daily[d2], "the stale abandon did nothing to the new day either")
        XCTAssertEqual(vm.run.day, d2)
        XCTAssertEqual(vm.run.attempt, 1)
        XCTAssertEqual(vm.run.idx, 0)
        XCTAssertEqual(vm.run.seed, UInt32(d2))
    }

    func testEveryRunActionNoticesMidnightFirst() async {
        func rolled(_ act: (GameViewModel) -> Void) async -> (GameViewModel, SaveStore) {
            let s = SaveStore(url: nil)
            let day = Day(d1)
            let vm = makeVM(store: s, day: day)
            day.value = d2
            act(vm)
            await vm.waitUntilSettled()
            return (vm, s)
        }
        for act in [{ (vm: GameViewModel) in vm.pick(0) }, { vm in vm.openRules() }, { vm in vm.bank() }] as [(GameViewModel) -> Void] {
            let (vm, s) = await rolled(act)
            XCTAssertEqual(vm.run.day, d2)
            XCTAssertEqual(vm.run.idx, 0, "the tap that arrived after midnight did not play yesterday's deck")
            XCTAssertNil(s.data.daily[d1])
            XCTAssertNil(vm.sheet)
        }
    }

    func testEndRunAfterMidnightFromTheFailSheetDoesNotCount() async {
        var r = dailyRun(day: d1)
        r.picks = 1
        let s = store(daily: r, mode: .daily)
        let day = Day(d1)
        let vm = makeVM(store: s, day: day)
        await pickCard0(vm)
        XCTAssertEqual(vm.sheet, .fail)
        day.value = d2
        vm.endRun()
        XCTAssertNil(s.data.daily[d1])
        XCTAssertEqual(vm.run.day, d2)
        XCTAssertNil(vm.sheet)
    }

    func testRefreshDayDoesNothingWithinTheSameDay() async {
        let day = Day(d1)
        let vm = makeVM(day: day)
        await pickCard0(vm)
        let run = vm.run
        vm.refreshDay()
        XCTAssertEqual(vm.run, run)
    }

    func testLaunchAfterMidnightStartsTheNewDayAndKeepsYesterdaysRecord() {
        var rec = DailyRecord(); rec.tries = 2
        let url = tempURL()
        var stale = dailyRun(day: d1, attempt: 3)
        stale.picks = 3
        _ = store(daily: stale, mode: .daily, records: [d1: rec], url: url)
        let s = SaveStore(url: url)
        let vm = makeVM(store: s, day: Day(d2))
        XCTAssertEqual(vm.run.day, d2)
        XCTAssertEqual(vm.run.attempt, 1)
        XCTAssertEqual(vm.run.picks, vm.run.stagePicksAtStart)
        XCTAssertEqual(s.data.daily[d1]?.tries, 2, "yesterday's count is untouched")
    }

    func testStaleDailyRunIsDroppedWhilePlayingFreeAndOnAShopToo() {
        var stale = dailyRun(day: d1)
        stale.phase = .shop
        stale.shopOffer = [.add, .bank, .cool]
        let s = store(daily: stale, free: GameEngine.newRun(seed: 5), mode: .free)
        let vm = makeVM(store: s, day: Day(d2), defaultMode: .daily)
        XCTAssertEqual(vm.mode, .free)
        XCTAssertNil(s.data.runs.daily, "discarded at launch")
        vm.switchMode(.daily)
        XCTAssertEqual(vm.run.day, d2)
        XCTAssertEqual(vm.run.attempt, 1)
    }

    func testMidnightWhileTheShopIsOpenStartsTheNewDay() {
        var r = dailyRun(day: d1, stage: 2)
        r.phase = .shop
        r.shopOffer = [.add, .bank, .cool]
        let day = Day(d1)
        let vm = makeVM(store: store(daily: r, mode: .daily), day: day)
        XCTAssertEqual(vm.sheet, .shop)
        day.value = d2
        vm.refreshDay()
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.stage, 1)
        XCTAssertEqual(vm.run.day, d2)
        XCTAssertFalse(vm.isLocked)
    }

    func testAFinishedRunFromYesterdayIsNotReplacedUnderTheResultSheet() async {
        let day = Day(d1)
        let s = store(daily: winnable(day: d1, attempt: 1), mode: .daily)
        let vm = makeVM(store: s, day: day)
        vm.bank()
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .result)
        day.value = d2
        vm.refreshDay()
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(vm.run.phase, .win)
        vm.retrySameDeck()                                    // the next attempt is for the new day
        XCTAssertEqual(vm.run.day, d2)
        XCTAssertEqual(vm.run.attempt, 1)
        XCTAssertEqual(s.data.daily[d1]?.winTry, 1)
    }

    // MARK: - Modes (02 §11)

    func testSwitchingModesKeepsBothRunsAndCountsNothing() async {
        let s = SaveStore(url: nil)
        let day = Day(d1)
        let vm = makeVM(store: s, day: day, seed: 20261116, defaultMode: .free)       // starts in free play
        XCTAssertEqual(vm.mode, .free)
        await pickCard0(vm)
        let free = vm.run
        XCTAssertEqual(free.idx, 1)

        vm.switchMode(.daily)
        XCTAssertEqual(vm.mode, .daily)
        XCTAssertEqual(vm.run.attempt, 1)
        await pickCard0(vm)
        await pickCard0(vm)
        let daily = vm.run
        XCTAssertEqual(daily.idx, 2)

        vm.switchMode(.free)
        XCTAssertEqual(vm.run, free, "free run is exactly where it was left")
        vm.switchMode(.daily)
        XCTAssertEqual(vm.run, daily, "so is the daily run")
        XCTAssertNil(s.data.daily[d1], "switching is not an attempt")
        XCTAssertNotNil(s.data.runs.free)
        XCTAssertNotNil(s.data.runs.daily)
        XCTAssertEqual(s.data.mode, .daily)
    }

    func testSwitchingToTheSameModeOrWhileLockedIsIgnored() {
        let vm = makeVM(day: Day(d1))
        let run = vm.run
        vm.switchMode(.daily)
        XCTAssertEqual(vm.run, run)
        vm.pick(0)                                       // locked while the pick resolves
        vm.switchMode(.free)
        XCTAssertEqual(vm.mode, .daily)
    }

    func testSwitchingWorksWithASheetOpenAndTheShopComesBack() {
        // 02 §11: only animations block the switch. Shop open in free play -> daily -> back: shop restored.
        var shop = GameEngine.newRun(seed: 5)
        shop.stage = 2
        shop.marks = [1]
        shop.coins = 7
        shop.phase = .shop
        shop.shopOffer = [.add, .bank, .cool]
        let vm = makeVM(store: store(free: shop, mode: .free), day: Day(d1))
        XCTAssertEqual(vm.sheet, .shop)
        XCTAssertTrue(vm.canSwitchMode)
        vm.switchMode(.daily)
        XCTAssertEqual(vm.mode, .daily)
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.attempt, 1)
        vm.switchMode(.free)
        XCTAssertEqual(vm.sheet, .shop)
        XCTAssertEqual(vm.run.shopOffer, [.add, .bank, .cool], "same shelf")
        XCTAssertEqual(vm.run.coins, 7)
    }

    func testSwitchingFromTheFailSheetAndTheRulesPanelRestoresThem() async {
        var r = dailyRun(day: d1)
        r.picks = 1
        let vm = makeVM(store: store(daily: r, mode: .daily), day: Day(d1))
        await pickCard0(vm)
        XCTAssertEqual(vm.sheet, .fail)
        vm.switchMode(.free)
        XCTAssertNil(vm.sheet)
        vm.switchMode(.daily)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .fail, "out of picks: the fail panel comes back")
        vm.endRun()
        vm.switchMode(.free)                                // from a result sheet
        vm.openRules()
        XCTAssertEqual(vm.sheet, .rules)
        vm.switchMode(.daily)
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.mode, .daily)
    }

    func testSwitchingIsBlockedWhileAnAnimationRunsOrTheAdPlays() async {
        var r = dailyRun(day: d1)
        r.picks = 1
        let vm = makeVM(store: store(daily: r, mode: .daily), day: Day(d1))
        vm.pick(0)
        XCTAssertFalse(vm.canSwitchMode)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .fail)
        vm.watchAd()
        XCTAssertFalse(vm.canSwitchMode, "mock ad playing")
        vm.switchMode(.free)
        XCTAssertEqual(vm.mode, .daily)
    }

    func testRelaunchRestoresTheLastMode() async {
        let url = tempURL()
        let day = Day(d1)
        let vm = makeVM(store: SaveStore(url: url), day: day)
        vm.switchMode(.free)
        let free = vm.run
        let again = makeVM(store: SaveStore(url: url), day: day)
        XCTAssertEqual(again.mode, .free)
        XCTAssertEqual(again.run, free)
    }

    func testFinishedDailyRunIsNotRestoredAndTheNextAttemptStarts() async {
        let s = SaveStore(url: nil)
        let day = Day(d1)
        let vm = makeVM(store: s, day: day, seed: 1, hooks: { var h = DebugHooks(); h.daily = true; h.fail = true; h.stage = 3; return h }())
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(s.data.daily[d1]?.tries, 1)
        vm.switchMode(.free)
        vm.switchMode(.daily)
        XCTAssertEqual(vm.run.attempt, 2)
        XCTAssertEqual(vm.run.phase, .play)
        XCTAssertEqual(s.data.daily[d1]?.tries, 1, "coming back is not another attempt")
    }

    func testDailyRunIsAlwaysLevelZeroEvenAfterPickingAFreeLevel() async {
        let s = SaveStore(url: nil)
        s.update { $0.unlock = 3 }
        let vm = makeVM(store: s, day: Day(d1))
        vm.startLevel(2)
        XCTAssertEqual(vm.mode, .daily, "level picks only work from the difficulty sheet")
        XCTAssertEqual(vm.run.lv, 0)
        vm.switchMode(.free)
        vm.switchMode(.daily)
        XCTAssertEqual(vm.run.lv, 0)
        XCTAssertEqual(vm.run.targetMul, 1.3)
    }

    func testDailyChipOpensTheSheetAndAPickedLevelStartsFreePlayKeepingTheDailyRun() async {
        let s = SaveStore(url: nil)
        s.update { $0.unlock = 3 }
        let vm = makeVM(store: s, day: Day(d1))
        await pickCard0(vm)
        let daily = vm.run
        vm.openDifficulty()
        XCTAssertEqual(vm.sheet, .difficulty)
        XCTAssertFalse(vm.difficultyReplacesRun, "nothing in progress in free play")
        vm.startLevel(2)
        XCTAssertEqual(vm.mode, .free)
        XCTAssertEqual(vm.run.lv, 2)
        XCTAssertEqual(s.data.lastLevel, 2)
        XCTAssertNil(s.data.daily[d1], "not an attempt")
        XCTAssertEqual(s.data.runs.daily, daily, "the daily run is saved untouched")
        vm.switchMode(.daily)
        XCTAssertEqual(vm.run, daily)
        // A free run in progress is replaced without counting: only the sheet warns.
        vm.switchMode(.free)
        await pickCard0(vm)
        XCTAssertTrue(vm.run.idx == 1)
        vm.switchMode(.daily)
        vm.openDifficulty()
        XCTAssertTrue(vm.difficultyReplacesRun)
        vm.startLevel(1)
        XCTAssertEqual(vm.run.lv, 1)
        XCTAssertEqual(vm.run.idx, 0)
        XCTAssertNil(s.data.daily[d1])
        vm.switchMode(.daily)
        XCTAssertEqual(vm.run, daily)
    }

    // MARK: - Result, copy, rules panel

    func testCopyPutsTheShareTextOnThePasteboardAndShowsAToast() {
        var h = DebugHooks(); h.daily = true; h.fail = true; h.stage = 3
        let vm = makeVM(day: Day(d1), seed: 1, hooks: h)
        XCTAssertEqual(vm.sheet, .result)
        UIPasteboard.general.string = "old"
        vm.copyResult()
        let expected = ShareText.make(vm.run)
        XCTAssertEqual(UIPasteboard.general.string, expected)
        XCTAssertTrue(expected.hasPrefix("INTUITION++ 11/16 今日挑戰\n第 1 次挑戰，止步第 3 關 · 總分 "))
        XCTAssertTrue(expected.hasSuffix("🟩🟩🟥⬜⬜⬜"), expected)
        XCTAssertEqual(vm.toast?.text, "已複製戰績")
        XCTAssertEqual(vm.toast?.overSheet, true)
    }

    func testCopyDoesNothingWithoutTheResultSheet() {
        let vm = makeVM(day: Day(d1))
        UIPasteboard.general.string = "keep"
        vm.copyResult()
        XCTAssertEqual(UIPasteboard.general.string, "keep")
    }

    func testRulesPanelMuteToggleIsSaved() {
        let s = SaveStore(url: nil)
        let vm = makeVM(store: s, day: Day(d1))
        vm.toggleMute()
        XCTAssertFalse(s.data.muted, "only from the rules panel")
        vm.openRules()
        vm.toggleMute()
        XCTAssertTrue(s.data.muted)
        XCTAssertTrue(vm.muted)
        vm.toggleMute()
        XCTAssertFalse(s.data.muted)
    }

    func testAbandonFromTheRulesPanelClosesItAndStartsTheNextAttempt() {
        let s = SaveStore(url: nil)
        let vm = makeVM(store: s, day: Day(d1))
        vm.openRules()
        vm.abandon()
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.attempt, 2)
        XCTAssertEqual(s.data.daily[d1]?.tries, 1)
        XCTAssertTrue(vm.toast?.text.contains("第 2 次") == true, vm.toast?.text ?? "")
    }

    func testAbandonIsIgnoredWhileLockedOrInTheShop() async {
        let s = SaveStore(url: nil)
        let vm = makeVM(store: s, day: Day(d1))
        vm.pick(0)
        vm.abandon()                                        // mid-pick
        XCTAssertNil(s.data.daily[d1])
        await vm.waitUntilSettled()
        var shop = dailyRun(day: d1, stage: 2)
        shop.phase = .shop
        shop.shopOffer = [.add, .bank, .cool]
        let vm2 = makeVM(store: store(daily: shop, mode: .daily), day: Day(d1))
        vm2.abandon()
        XCTAssertEqual(vm2.run.phase, .shop)
    }

    func testFreeAbandonEndsTheRunWithoutTouchingTheDailyLedger() async {
        let s = SaveStore(url: nil)
        let vm = makeVM(store: s, day: Day(d1), seed: 20261116, defaultMode: .free)
        await pickCard0(vm)
        let oldSeed = vm.run.seed
        vm.abandon()
        XCTAssertEqual(vm.mode, .free)
        XCTAssertNotEqual(vm.run.seed, oldSeed, "a new deck")
        XCTAssertEqual(vm.run.idx, 0)
        XCTAssertTrue(s.data.daily.isEmpty)
    }

    func testFreeAbandonOfAnUntouchedRunJustDealsANewOne() {
        let s = SaveStore(url: nil)
        let vm = makeVM(store: s, day: Day(d1), seed: 20261116, defaultMode: .free)
        vm.abandon()
        XCTAssertEqual(vm.run.seed, 777)
        XCTAssertFalse(vm.run.abandoned)
    }

    func testResultButtonsInDaily() async {
        var h = DebugHooks(); h.daily = true; h.fail = true; h.stage = 3
        let s = SaveStore(url: nil)
        let vm = makeVM(store: s, day: Day(d1), seed: 1, hooks: h)
        vm.retrySameDeck()                                  // 「再挑戰一次（第 2 次）」
        XCTAssertEqual(vm.mode, .daily)
        XCTAssertEqual(vm.run.attempt, 2)
        XCTAssertEqual(vm.run.seed, UInt32(d1))
        XCTAssertEqual(vm.run.stage, 1)
    }

    func testGoingToFreePlayFromTheResultSheet() {
        var h = DebugHooks(); h.daily = true; h.fail = true; h.stage = 3
        let vm = makeVM(day: Day(d1), seed: 1, hooks: h)
        vm.switchMode(.free)
        XCTAssertEqual(vm.mode, .free)
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.day, d1)
    }
}
