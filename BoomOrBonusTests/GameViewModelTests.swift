//
//  GameViewModelTests.swift
//  BoomOrBonusTests
//

import XCTest
@testable import BoomOrBonus

@MainActor
final class GameViewModelTests: XCTestCase {

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

    /// Instant sleeper: still yields so the flow task interleaves like the real one.
    private let instant: GameViewModel.Sleeper = { _ in await Task.yield() }

    private func makeVM(
        store: SaveStore = SaveStore(url: nil),
        seed: UInt32? = 20261116,
        timing: GameViewModel.Timing = .standard,
        sleeper: GameViewModel.Sleeper? = nil
    ) -> GameViewModel {
        GameViewModel(
            store: store, launchSeed: seed, timing: timing,
            sleeper: sleeper ?? instant,
            reduceMotion: { false }, feedbackEnabled: false,
            randomSeed: { 12345 }
        )
    }

    private func store(with run: RunState) -> SaveStore {
        let s = SaveStore(url: nil)
        s.update { $0.runs.free = run }
        return s
    }

    // MARK: - Tap lock

    func testSecondPickWhileResolvingIsIgnored() async {
        // Real (short) delays so the second tap lands while the first pick is still in flight.
        var t = GameViewModel.Timing()
        t.tickGap = 0.01; t.reveal = 0.01; t.deal = 0.05
        let vm = makeVM(timing: t, sleeper: { s in try? await Task.sleep(nanoseconds: UInt64(s * 1e9)) })
        let pair0 = vm.run.pair
        let picks0 = vm.run.picks

        vm.pick(0)
        vm.pick(1)                                 // same run loop: locked
        try? await Task.sleep(nanoseconds: 15_000_000)
        vm.pick(1)                                 // mid-animation: still locked
        vm.pick(0)
        await vm.waitUntilSettled()

        XCTAssertEqual(vm.run.idx, 1, "exactly one pick must have been applied")
        XCTAssertLessThanOrEqual(picks0 - vm.run.picks, 1)
        XCTAssertNotEqual(vm.run.pair, pair0, "next pair is dealt after the pick")
        XCTAssertFalse(vm.isLocked, "unlocked after the deal")
        // And it is playable again.
        vm.pick(0)
        XCTAssertTrue(vm.isLocked)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.run.idx, 2)
    }

    func testPickIsIgnoredOutsidePlayPhaseAndForBadIndex() async {
        let vm = makeVM()
        vm.pick(2)
        vm.pick(-1)
        XCTAssertFalse(vm.isLocked)
        XCTAssertEqual(vm.run.idx, 0)
    }

    // MARK: - Save / restore

    func testSaveThenLoadRestoresSameRun() async throws {
        let url = tempURL()
        let vm1 = makeVM(store: SaveStore(url: url))
        vm1.pick(0)
        await vm1.waitUntilSettled()
        vm1.pick(1)
        await vm1.waitUntilSettled()
        XCTAssertEqual(vm1.run.idx, 2)

        // New store reading the same file = app relaunch (no -seed).
        let vm2 = makeVM(store: SaveStore(url: url), seed: nil)
        XCTAssertEqual(vm2.run, vm1.run)
        XCTAssertEqual(vm2.run.stage, vm1.run.stage)
        XCTAssertEqual(vm2.run.idx, vm1.run.idx)
        XCTAssertEqual(vm2.run.value, vm1.run.value)
        XCTAssertEqual(vm2.run.pair, vm1.run.pair)
        XCTAssertEqual(vm2.faces.map(\.card), vm1.run.pair)
    }

    func testBlessingsSurviveSaveRoundTrip() throws {
        var run = GameEngine.newRun(seed: 7)
        run.blessings = [.add: 2, .grit: 1]
        let s = SaveStore(url: tempURL())
        s.update { $0.runs.free = run }
        let again = SaveStore(url: tempURLs[0])
        XCTAssertEqual(again.data.runs.free, run)
    }

    func testRestoreRulesFollowSpec() {
        var run = GameEngine.newRun(seed: 99)
        run.version = 5
        XCTAssertNil(store(with: run).restorableFreeRun(), "version mismatch")
        run.version = 6
        run.phase = .over
        XCTAssertNil(store(with: run).restorableFreeRun(), "over is not restored")
        run.phase = .win
        XCTAssertNil(store(with: run).restorableFreeRun(), "win is not restored")
        run.phase = .shop
        XCTAssertNotNil(store(with: run).restorableFreeRun(), "shop (stage clear) is restored")
        run.phase = .play
        XCTAssertNotNil(store(with: run).restorableFreeRun())
    }

    func testRestoredShopPhaseReopensShop() {
        var run = GameEngine.newRun(seed: 99)
        run.phase = .shop
        let vm = makeVM(store: store(with: run), seed: nil)
        XCTAssertEqual(vm.sheet, .shop)
        XCTAssertFalse(vm.canInteract)
    }

    func testFinishedRunStartsFreshOnRestore() {
        var run = GameEngine.newRun(seed: 99)
        run.phase = .over
        let vm = makeVM(store: store(with: run), seed: nil)
        XCTAssertEqual(vm.run.seed, 12345, "fresh run from randomSeed()")
        XCTAssertEqual(vm.run.phase, .play)
        XCTAssertEqual(vm.run.stage, 1)
    }

    // MARK: - Seed hook

    func testSeedPathDealsVectorPair0() throws {
        let vm = makeVM(seed: 20261116)
        let v = try loadVectors()["genPair_daily20261116_stage1_value0"] as! [String: Any]
        let pairs = v["pairs"] as! [[[String: Any]]]
        let expected = pairs[0]
        XCTAssertEqual(vm.run.seed, 20261116)
        XCTAssertEqual(vm.run.mode, .free)
        XCTAssertEqual(vm.run.pair.count, 2)
        for (i, e) in expected.enumerated() {
            let c = vm.run.pair[i]
            XCTAssertEqual(c.danger, e["d"] as? Int, "card \(i) danger")
            XCTAssertEqual(c.p, (e["p"] as! NSNumber).doubleValue, accuracy: 1e-9)
            XCTAssertEqual(c.op, (e["op"] as! String) == "+" ? .add : .mul)
            XCTAssertEqual(c.n, (e["n"] as! NSNumber).doubleValue, accuracy: 1e-9)
            XCTAssertEqual(c.boom, e["boom"] as? Bool)
            // What is on screen is what the engine dealt.
            XCTAssertEqual(vm.faces[i].card, c)
        }
    }

    func testSeedIgnoresSave() {
        var old = GameEngine.newRun(seed: 5)
        old.value = 33
        let vm = makeVM(store: store(with: old), seed: 20261116)
        XCTAssertEqual(vm.run.seed, 20261116)
        XCTAssertEqual(vm.run.value, 0)
    }

    func testDebugSeedArgumentParsing() {
        #if DEBUG
        XCTAssertEqual(GameViewModel.debugLaunchSeed(arguments: ["app", "-seed", "20261116"]), 20261116)
        XCTAssertNil(GameViewModel.debugLaunchSeed(arguments: ["app", "-seed"]))
        XCTAssertNil(GameViewModel.debugLaunchSeed(arguments: ["app", "-seed", "abc"]))
        XCTAssertNil(GameViewModel.debugLaunchSeed(arguments: ["app"]))
        #endif
    }

    // MARK: - Fail and revive

    private func lastPickRun() -> RunState {
        var r = GameEngine.newRun(seed: 20261116)
        r.picks = 1
        r.shield = 0
        r.pair = [boomCard(), boomCard()]
        return r
    }

    func testFailOpensFailSheetThenMockReviveGivesPicksBack() async {
        let vm = makeVM(store: store(with: lastPickRun()), seed: nil)
        vm.pick(0)
        await vm.waitUntilSettled()

        XCTAssertEqual(vm.run.picks, 0)
        XCTAssertEqual(vm.sheet, .fail)
        XCTAssertFalse(vm.run.adUsed)
        XCTAssertFalse(vm.canInteract)

        vm.watchAd()
        XCTAssertNil(vm.sheet)
        XCTAssertTrue(vm.adPlaying)
        XCTAssertFalse(vm.canInteract, "no taps during the ad")
        await vm.waitUntilSettled()

        var expected = lastPickRun()
        _ = GameEngine.pickCard(&expected, index: 0)
        GameEngine.reviveWithAd(&expected)
        XCTAssertEqual(vm.run.picks, 2, "engine reviveWithAd sets picks = 2")
        XCTAssertTrue(vm.run.adUsed)
        XCTAssertEqual(vm.run.pair, expected.pair)
        XCTAssertFalse(vm.adPlaying)
        XCTAssertNil(vm.sheet)
        XCTAssertTrue(vm.canInteract)
    }

    func testSecondFailAfterAdGoesStraightToResult() async {
        var r = lastPickRun()
        r.adUsed = true
        let vm = makeVM(store: store(with: r), seed: nil)
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(vm.run.phase, .over)
        XCTAssertEqual(vm.run.marks, [0])
    }

    func testEndRunFromFailSheetShowsResultAndPlayAgainStartsFresh() async {
        let vm = makeVM(store: store(with: lastPickRun()), seed: nil)
        vm.pick(0)
        await vm.waitUntilSettled()
        vm.endRun()
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(vm.run.phase, .over)
        vm.watchAd()                               // cannot revive after ending
        XCTAssertFalse(vm.adPlaying)
        vm.startNewRun()
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.phase, .play)
        XCTAssertEqual(vm.run.stage, 1)
        XCTAssertEqual(vm.run.picks, vm.run.stagePicksAtStart)
        XCTAssertTrue(vm.canInteract)
    }

    // MARK: - Stage clear

    func testBankThenNextStage() async {
        var r = GameEngine.newRun(seed: seedWithStage1Mod(.heat))
        r.value = GameEngine.target(r)
        r.picks = r.stagePicksAtStart - 1          // at least one pick used
        let vm = makeVM(store: store(with: r), seed: nil)
        XCTAssertTrue(vm.canClear)
        vm.bank()
        vm.bank()                                  // double tap: ignored
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.run.phase, .shop)
        XCTAssertEqual(vm.sheet, .shop)
        XCTAssertEqual(vm.run.marks.count, 1)
        XCTAssertFalse(vm.run.lastRewardParts.isEmpty)

        vm.nextStage()
        XCTAssertEqual(vm.run.stage, 2)
        XCTAssertEqual(vm.run.value, 0)
        XCTAssertEqual(vm.run.phase, .play)
        XCTAssertNil(vm.sheet)
        XCTAssertTrue(vm.canInteract)
    }

    func testBankIsIgnoredBelowTarget() {
        let vm = makeVM()
        vm.bank()
        XCTAssertFalse(vm.isLocked)
        XCTAssertEqual(vm.run.phase, .play)
    }

    // MARK: - Items

    func testItemsConsumeInventoryAndRollRedealsPair() {
        let vm = makeVM()
        let before = vm.run.pair
        XCTAssertEqual(vm.run.inventory.roll, 1)
        vm.useItem(.roll)
        XCTAssertEqual(vm.run.inventory.roll, 0)
        XCTAssertEqual(vm.run.rerolls, 1)
        XCTAssertNotEqual(vm.run.pair, before)
        XCTAssertEqual(vm.faces.map(\.card), vm.run.pair)
        vm.useItem(.roll)                          // none left
        XCTAssertEqual(vm.run.rerolls, 1)

        vm.useItem(.peek)
        XCTAssertTrue(vm.run.peekArmed)
        XCTAssertEqual(vm.run.inventory.peek, 0)
        XCTAssertTrue(vm.faces.allSatisfy(\.peek))
        vm.useItem(.dbl)                           // dbl = 0 at start
        XCTAssertFalse(vm.run.doubleArmed)
    }

    func testItemsLockedWhilePickResolves() {
        let vm = makeVM()
        vm.pick(0)
        vm.useItem(.roll)
        XCTAssertEqual(vm.run.inventory.roll, 1)
    }
}
