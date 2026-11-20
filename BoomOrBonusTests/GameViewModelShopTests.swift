//
//  GameViewModelShopTests.swift
//  BoomOrBonusTests
//
//  Phase 3: shop, endless, difficulty, unlock and the result buttons.
//

import XCTest
@testable import BoomOrBonus

@MainActor
final class GameViewModelShopTests: XCTestCase {

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

    private let instant: GameViewModel.Sleeper = { _ in await Task.yield() }

    private func makeVM(store: SaveStore, seed: UInt32? = nil) -> GameViewModel {
        GameViewModel(store: store, launchSeed: seed, sleeper: instant,
                      reduceMotion: { false }, feedbackEnabled: false, randomSeed: { 777 })
    }

    private func store(with run: RunState, unlock: Int = 0, lastLevel: Int = 0, url: URL? = nil) -> SaveStore {
        let s = SaveStore(url: url)
        s.update {
            $0.runs.free = run
            $0.unlock = unlock
            $0.lastLevel = lastLevel
        }
        return s
    }

    /// A run one tap away from banking `stage` (target met, one pick used).
    private func ready(stage: Int = 1, lv: Int = 0, coins: Int = 0, blessings: [BlessingID: Int] = [:],
                       marks: [Int]? = nil, endless: Bool = false) -> RunState {
        var r = GameEngine.newRun(seed: seedWithStage1Mod(.heat), lv: lv)
        r.stage = stage
        r.endless = endless
        r.blessings = blessings
        r.coins = coins
        r.marks = marks ?? Array(repeating: 1, count: stage - 1)
        r.picks = GameEngine.stagePicks(r)
        r.stagePicksAtStart = r.picks
        r.value = GameEngine.target(r)
        r.picks -= 1
        r.pair = GameEngine.genPair(r)
        return r
    }

    /// VM that has just banked `run` and shows the shop (or the win result).
    private func banked(_ run: RunState, unlock: Int = 0, url: URL? = nil) async -> GameViewModel {
        let vm = makeVM(store: store(with: run, unlock: unlock, url: url))
        vm.bank()
        await vm.waitUntilSettled()
        return vm
    }

    // MARK: - Shop

    func testClearOpensShopWithShelfFromSeed() async {
        let vm = await banked(ready(coins: 20))
        XCTAssertEqual(vm.sheet, .shop)
        XCTAssertEqual(vm.run.phase, .shop)
        XCTAssertEqual(vm.run.shopOffer.count, 3)
        XCTAssertEqual(vm.run.shopOffer.compactMap { $0 }, Shop.shopOffer(vm.run))
        XCTAssertEqual(vm.nextStageNumber, 2)
        XCTAssertEqual(vm.nextBoss, .fog)
        XCTAssertEqual(vm.nextTarget, 34)
    }

    /// A shop run with a fixed shelf, so the tests do not depend on the seed.
    private func shopRun(coins: Int, offer: [BlessingID?], blessings: [BlessingID: Int] = [:]) -> RunState {
        var r = ready(coins: coins, blessings: blessings)
        r.phase = .shop
        r.shopOffer = offer
        return r
    }

    func testBuyBlessingTwiceOnTheSameSlotBuysOnce() {
        let vm = makeVM(store: store(with: shopRun(coins: 30, offer: [.add, .bank, .cool])))
        vm.buyBlessing(.add)
        vm.buyBlessing(.add)
        XCTAssertEqual(vm.run.level(.add), 1)
        XCTAssertEqual(vm.run.coins, 30 - BlessingID.add.basePrice)
        XCTAssertNil(vm.run.shopOffer[0], "bought slot shows 已購買")
    }

    func testShopLockIgnoresATapOnADifferentAffordableSlot() async {
        let vm = makeVM(store: store(with: shopRun(coins: 30, offer: [.add, .bank, .cool])))
        XCTAssertTrue(vm.canBuy(.bank))
        vm.buyBlessing(.add)
        vm.buyBlessing(.bank)                     // different slot, affordable, same run loop: locked out
        vm.buyItem(.peek)
        vm.rerollShop()
        XCTAssertEqual(vm.run.level(.add), 1)
        XCTAssertFalse(vm.run.has(.bank), "the lock, not the slot, blocked this")
        XCTAssertEqual(vm.run.inventory.peek, 1)
        XCTAssertEqual(vm.run.shopRerolls, 0)
        XCTAssertEqual(vm.run.coins, 30 - BlessingID.add.basePrice)
        await vm.waitUntilSettled()               // lock released after 0.25s
        vm.buyBlessing(.bank)
        XCTAssertEqual(vm.run.level(.bank), 1)
    }

    func testBuyBlessingNotOnShelfIsIgnored() {
        let vm = makeVM(store: store(with: shopRun(coins: 99, offer: [.add, .bank, .cool])))
        vm.buyBlessing(.defuse)
        XCTAssertFalse(vm.run.has(.defuse))
        XCTAssertEqual(vm.run.coins, 99)
    }

    func testUnaffordableBlessingOnShelfIsIgnored() {
        let vm = makeVM(store: store(with: shopRun(coins: 3, offer: [.add, .bank, .cool])))
        XCTAssertFalse(vm.canBuy(.cool))           // $5
        vm.buyBlessing(.cool)
        XCTAssertFalse(vm.run.has(.cool))
        XCTAssertEqual(vm.run.coins, 3)
        XCTAssertEqual(vm.run.shopOffer[2], .cool, "slot is still there")
        XCTAssertFalse(vm.canBuy(.add), "$4 is also out of reach at $3")
    }

    func testBuyItemDoubleTapBuysOnce() async {
        let vm = await banked(ready(coins: 20))
        let coins0 = vm.run.coins
        let peek0 = vm.run.inventory.peek
        vm.buyItem(.peek)
        vm.buyItem(.peek)
        XCTAssertEqual(vm.run.inventory.peek, peek0 + 1)
        XCTAssertEqual(vm.run.coins, coins0 - 3)
        await vm.waitUntilSettled()
        vm.buyItem(.shield)
        XCTAssertEqual(vm.run.shield, 2)
        XCTAssertEqual(vm.run.coins, coins0 - 3 - 4)
    }

    func testItemWithoutEnoughCoinsIsIgnored() async {
        var r = ready()
        r.blessings = [:]
        let vm = await banked(r)
        var poor = vm.run
        poor.coins = 2
        let vm2 = makeVM(store: store(with: poor))
        vm2.buyItem(.peek)                        // $3
        XCTAssertEqual(vm2.run.coins, 2)
        XCTAssertEqual(vm2.run.inventory.peek, poor.inventory.peek)
        XCTAssertFalse(vm2.canBuy(.peek))
        XCTAssertTrue(vm2.canBuy(.roll))
    }

    func testRerollCostsOneAndRegeneratesTheShelf() async {
        let vm = await banked(ready(coins: 10))
        let coins0 = vm.run.coins
        let before = vm.run.shopOffer
        vm.rerollShop()
        vm.rerollShop()                           // double tap: once
        XCTAssertEqual(vm.run.coins, coins0 - 1)
        XCTAssertEqual(vm.run.shopRerolls, 1)
        var expected = vm.run
        expected.shopRerolls = 1
        XCTAssertEqual(vm.run.shopOffer.compactMap { $0 }, Shop.shopOffer(expected))
        XCTAssertNotEqual(vm.run.shopOffer, before)
        await vm.waitUntilSettled()
        vm.rerollShop()
        XCTAssertEqual(vm.run.shopRerolls, 2)
        XCTAssertEqual(vm.run.coins, coins0 - 2)
    }

    func testRerollWithoutMoneyDoesNothing() {
        var r = ready()
        r.phase = .shop
        r.coins = 0
        r.shopOffer = Shop.shopOffer(r)
        let vm = makeVM(store: store(with: r))
        XCTAssertEqual(vm.sheet, .shop)
        XCTAssertFalse(vm.canReroll)
        vm.rerollShop()
        XCTAssertEqual(vm.run.coins, 0)
        XCTAssertEqual(vm.run.shopRerolls, 0)
        XCTAssertEqual(vm.run.shopOffer, r.shopOffer)
    }

    func testRerollIsFlatOneDollarAtLegend() async {
        let vm = await banked(ready(lv: 5, coins: 10))
        let coins0 = vm.run.coins
        vm.rerollShop()
        XCTAssertEqual(vm.run.coins, coins0 - 1)
    }

    func testLegendPricesAreOneHigher() async {
        let vm = await banked(ready(lv: 5, coins: 50))
        XCTAssertEqual(vm.price(ItemID.peek.basePrice), 4)
        XCTAssertEqual(vm.price(BlessingID.defuse.basePrice), 8)
        let coins0 = vm.run.coins
        vm.buyItem(.roll)
        XCTAssertEqual(vm.run.coins, coins0 - 3)
        await vm.waitUntilSettled()
        let id = vm.run.shopOffer.compactMap { $0 }[0]
        let c1 = vm.run.coins
        vm.buyBlessing(id)
        XCTAssertEqual(vm.run.coins, c1 - (id.basePrice + 1))
        // Normal difficulty for contrast.
        let normal = await banked(ready(lv: 0, coins: 50))
        XCTAssertEqual(normal.price(ItemID.peek.basePrice), 3)
    }

    func testBlessingCapOfFive() async {
        let five: [BlessingID: Int] = [.cool: 1, .gamb: 1, .hot: 1, .grit: 1, .eye: 1]
        var r = ready(coins: 99, blessings: five)
        r.phase = .shop
        r.shopOffer = [.defuse, .add, .bank]
        let vm = makeVM(store: store(with: r))
        XCTAssertEqual(vm.sheet, .shop)
        XCTAssertFalse(vm.canBuy(.defuse), "sixth kind is blocked")
        XCTAssertFalse(vm.canBuy(.bank))
        XCTAssertFalse(vm.canBuy(.add), "not owned and the cap is full")
        vm.buyBlessing(.defuse)
        XCTAssertFalse(vm.run.has(.defuse))
        XCTAssertEqual(vm.run.blessings.count, 5)
    }

    func testStackableBlessingStaysBuyableAtTheCap() {
        let five: [BlessingID: Int] = [.add: 1, .cool: 1, .gamb: 1, .hot: 1, .grit: 1]
        var r = ready(coins: 99, blessings: five)
        r.phase = .shop
        r.shopOffer = [.add, .defuse, .cool]
        let vm = makeVM(store: store(with: r))
        XCTAssertTrue(vm.canBuy(.add))
        XCTAssertFalse(vm.canBuy(.defuse))
        XCTAssertFalse(vm.canBuy(.cool), "non-stackable owned blessing cannot be bought again")
        vm.buyBlessing(.add)
        XCTAssertEqual(vm.run.level(.add), 2)
        XCTAssertEqual(vm.run.blessings.count, 5)
        XCTAssertNil(vm.run.shopOffer[0])
    }

    func testNextStageLeavesShopAndEyeGivesAPeek() async {
        let vm = await banked(ready(coins: 5, blessings: [.eye: 1]))
        let peek0 = vm.run.inventory.peek
        vm.nextStage()
        vm.nextStage()                            // second tap: ignored
        XCTAssertEqual(vm.run.stage, 2)
        XCTAssertEqual(vm.run.inventory.peek, peek0 + 1)
        XCTAssertNil(vm.sheet)
        XCTAssertTrue(vm.run.shopOffer.isEmpty)
        XCTAssertTrue(vm.toast?.text.contains("千里眼") == true)
        XCTAssertTrue(vm.canInteract)
    }

    func testShopSaveAndRestoreKeepsTheSameShelf() async {
        let url = tempURL()
        let vm = await banked(ready(coins: 30), url: url)
        vm.rerollShop()
        await vm.waitUntilSettled()
        let id = vm.run.shopOffer.compactMap { $0 }[0]
        vm.buyBlessing(id)
        await vm.waitUntilSettled()
        let shelf = vm.run.shopOffer
        XCTAssertTrue(shelf.contains(where: { $0 == nil }))

        // App relaunch: new store reading the same file, no -seed.
        let vm2 = makeVM(store: SaveStore(url: url))
        XCTAssertEqual(vm2.sheet, .shop)
        XCTAssertEqual(vm2.run.phase, .shop)
        XCTAssertEqual(vm2.run.shopOffer, shelf, "identical shelf, bought slot still sold out")
        XCTAssertEqual(vm2.run.coins, vm.run.coins)
        XCTAssertEqual(vm2.run.shopRerolls, 1)
        XCTAssertEqual(vm2.run.blessings, vm.run.blessings)
        XCTAssertEqual(vm2.run.lastRewardParts, vm.run.lastRewardParts)
        XCTAssertFalse(vm2.canInteract)
    }

    // MARK: - Unlock

    func testFullSixStageClearUnlocksNextLevel() async {
        let vm = await banked(ready(stage: 6), unlock: 0)
        XCTAssertEqual(vm.run.phase, .win)
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(vm.unlock, 1)
        XCTAssertEqual(vm.run.newlyUnlockedLevel, 1)
    }

    func testUnlockIsPersisted() async {
        let url = tempURL()
        _ = await banked(ready(stage: 6), unlock: 0, url: url)
        XCTAssertEqual(SaveStore(url: url).data.unlock, 1)
    }

    func testClearingStageFiveDoesNotUnlock() async {
        let vm = await banked(ready(stage: 5), unlock: 0)
        XCTAssertEqual(vm.run.phase, .shop)
        XCTAssertEqual(vm.unlock, 0)
        XCTAssertNil(vm.run.newlyUnlockedLevel)
    }

    func testFailingStageSixDoesNotUnlock() async {
        var r = ready(stage: 6)
        r.value = 0
        r.picks = 1
        r.shield = 0
        r.adUsed = true
        r.pair = [boomCard(), boomCard()]
        let vm = makeVM(store: store(with: r, unlock: 0))
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.run.phase, .over)
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(vm.run.marks, [1, 1, 1, 1, 1, 0])
        XCTAssertEqual(vm.unlock, 0)
        XCTAssertNil(vm.run.newlyUnlockedLevel)
    }

    func testFailPanelEndRunAtStageSixDoesNotUnlock() async {
        var r = ready(stage: 6)
        r.value = 0
        r.picks = 1
        r.shield = 0
        r.pair = [boomCard(), boomCard()]
        let vm = makeVM(store: store(with: r, unlock: 0))
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .fail)
        vm.endRun()
        XCTAssertEqual(vm.unlock, 0)
    }

    func testAbandoningARunDoesNotUnlock() async {
        let vm = makeVM(store: store(with: ready(stage: 6), unlock: 0))
        XCTAssertTrue(vm.runInProgress)
        vm.openDifficulty()
        vm.startLevel(0)
        XCTAssertEqual(vm.unlock, 0)
        XCTAssertEqual(vm.run.stage, 1)
        XCTAssertNil(vm.run.newlyUnlockedLevel)
    }

    func testReclearingAnAlreadyUnlockedLevelShowsNoUnlock() async {
        let vm = await banked(ready(stage: 6, lv: 0), unlock: 3)
        XCTAssertEqual(vm.run.phase, .win)
        XCTAssertEqual(vm.unlock, 3)
        XCTAssertNil(vm.run.newlyUnlockedLevel)
    }

    func testClearingTheNewestLevelUnlocksTheNextOne() async {
        let vm = await banked(ready(stage: 6, lv: 2), unlock: 2)
        XCTAssertEqual(vm.unlock, 3)
        XCTAssertEqual(vm.run.newlyUnlockedLevel, 3)
    }

    func testLegendClearUnlocksNothingMore() async {
        let vm = await banked(ready(stage: 6, lv: 5), unlock: 5)
        XCTAssertEqual(vm.unlock, 5)
        XCTAssertNil(vm.run.newlyUnlockedLevel)
    }

    // MARK: - Endless and deepest

    func testContinueIntoEndlessGoesThroughShopToStageSeven() async {
        let vm = await banked(ready(stage: 6, coins: 4))
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertFalse(vm.run.endless)
        let coins = vm.run.coins
        vm.startEndless()
        XCTAssertTrue(vm.run.endless)
        XCTAssertEqual(vm.run.phase, .shop)
        XCTAssertEqual(vm.sheet, .shop)
        XCTAssertEqual(vm.run.shopOffer.count, 3)
        XCTAssertEqual(vm.run.coins, coins, "coins, blessings and items carry over")
        XCTAssertEqual(vm.nextStageNumber, 7)
        XCTAssertEqual(vm.nextTarget, GameEngine.targetAt(stage: 7, lv: 0))
        vm.nextStage()
        XCTAssertEqual(vm.run.stage, 7)
        XCTAssertEqual(vm.run.phase, .play)
        XCTAssertNil(vm.sheet)
        XCTAssertTrue(vm.canInteract)
        XCTAssertEqual(vm.run.marks.count, 6)
    }

    func testEndlessIsOnlyOfferedAfterAWin() async {
        let vm = makeVM(store: store(with: ready(stage: 3)))
        vm.startEndless()
        XCTAssertFalse(vm.run.endless)
        let again = await banked(ready(stage: 6))
        again.startEndless()
        again.startEndless()                      // second call: not on the result sheet any more
        XCTAssertEqual(again.sheet, .shop)
        XCTAssertTrue(again.run.endless)
    }

    func testEndlessBossesRotateShortFogShakyCrush() {
        let order = (7...20).compactMap { GameEngine.bossOf(stage: $0) }
        XCTAssertEqual(order, [.short, .fog, .shaky, .crush, .short, .fog, .shaky])
    }

    func testDeepestTracksEndlessClears() async {
        let url = tempURL()
        let vm = await banked(ready(stage: 6), url: url)
        XCTAssertEqual(vm.deepest, 0, "a normal win does not count")
        vm.startEndless()
        XCTAssertEqual(vm.deepest, 6)
        vm.nextStage()
        // Clear stage 7 and 8 in endless.
        for stage in 7...8 {
            var r = vm.run
            XCTAssertEqual(r.stage, stage)
            r.value = GameEngine.target(r)
            r.picks = r.stagePicksAtStart - 1
            let next = makeVM(store: store(with: r, unlock: 1, url: url))
            next.bank()
            await next.waitUntilSettled()
            XCTAssertEqual(next.sheet, .shop)
            XCTAssertEqual(next.deepest, stage)
            if stage == 7 { next.nextStage(); XCTAssertEqual(next.run.stage, 8) }
            if stage == 7 { return await continueTo8(from: next) }
        }
    }

    private func continueTo8(from vm: GameViewModel) async {
        var r = vm.run
        r.value = GameEngine.target(r)
        r.picks = r.stagePicksAtStart - 1
        let again = makeVM(store: store(with: r, unlock: 1))
        again.bank()
        await again.waitUntilSettled()
        XCTAssertEqual(again.deepest, 8)
        XCTAssertEqual(SaveStore(url: nil).data.deepest, 0)
    }

    func testDeepestNeverGoesDown() async {
        let s = store(with: ready(stage: 7, marks: [1, 1, 1, 1, 1, 1], endless: true), unlock: 1)
        s.update { $0.deepest = 12 }
        let vm = makeVM(store: s)
        vm.bank()
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.deepest, 12)
    }

    func testEndlessFailKeepsMarksAndResultKnowsEndless() async {
        var r = ready(stage: 8, marks: [1, 1, 1, 1, 1, 1, 1], endless: true)
        r.value = 0
        r.picks = 1
        r.shield = 0
        r.adUsed = true
        r.pair = [boomCard(), boomCard()]
        let vm = makeVM(store: store(with: r, unlock: 1))
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(vm.run.marks.count, 8)
        XCTAssertEqual(vm.run.marks.last, 0)
        XCTAssertTrue(vm.run.endless)
    }

    // MARK: - Difficulty and result buttons

    func testNewFreeRunUsesMinOfLastLevelAndUnlock() {
        var done = GameEngine.newRun(seed: 1)
        done.phase = .over
        XCTAssertEqual(makeVM(store: store(with: done, unlock: 3, lastLevel: 2)).run.lv, 2)
        XCTAssertEqual(makeVM(store: store(with: done, unlock: 1, lastLevel: 4)).run.lv, 1)
        XCTAssertEqual(makeVM(store: store(with: done, unlock: 0, lastLevel: 0)).run.lv, 0)
    }

    func testPickingALevelStartsANewRunAndSavesLastLevel() {
        let url = tempURL()
        let vm = makeVM(store: store(with: GameEngine.newRun(seed: 5), unlock: 2, url: url))
        vm.openDifficulty()
        XCTAssertEqual(vm.sheet, .difficulty)
        XCTAssertFalse(vm.runInProgress)
        vm.startLevel(2)
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.lv, 2)
        XCTAssertEqual(vm.run.seed, 777)
        XCTAssertEqual(vm.run.stage, 1)
        XCTAssertEqual(vm.lastLevel, 2)
        XCTAssertEqual(SaveStore(url: url).data.lastLevel, 2)
        XCTAssertEqual(vm.run.picks, 6, "老手: one pick fewer")
        XCTAssertTrue(vm.canInteract)
    }

    func testLockedLevelCannotBePicked() {
        let vm = makeVM(store: store(with: GameEngine.newRun(seed: 5), unlock: 1))
        vm.openDifficulty()
        let seed0 = vm.run.seed
        vm.startLevel(2)
        vm.startLevel(5)
        vm.startLevel(-1)
        vm.startLevel(9)
        XCTAssertEqual(vm.sheet, .difficulty)
        XCTAssertEqual(vm.run.seed, seed0)
        XCTAssertEqual(vm.run.lv, 0)
        XCTAssertEqual(vm.lastLevel, 0)
        vm.startLevel(1)
        XCTAssertEqual(vm.run.lv, 1)
    }

    func testDifficultySheetOpensOnlyWhenPlayable() async {
        let vm = makeVM(store: store(with: GameEngine.newRun(seed: 5)))
        vm.pick(0)
        vm.openDifficulty()                       // animation in flight
        XCTAssertNil(vm.sheet)
        await vm.waitUntilSettled()
        vm.openDifficulty()
        XCTAssertEqual(vm.sheet, .difficulty)
        vm.closeDifficulty()
        XCTAssertNil(vm.sheet)
    }

    func testChangeLevelFromResultAndCancelGoesBack() async {
        var r = ready()
        r.value = 0
        r.picks = 1
        r.shield = 0
        r.adUsed = true
        r.pair = [boomCard(), boomCard()]
        let vm = makeVM(store: store(with: r, unlock: 1))
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .result)
        vm.openDifficulty()
        XCTAssertEqual(vm.sheet, .difficulty)
        XCTAssertFalse(vm.runInProgress, "the finished run is not abandoned")
        vm.closeDifficulty()
        XCTAssertEqual(vm.sheet, .result)
        vm.openDifficulty()
        vm.startLevel(1)
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.lv, 1)
        XCTAssertEqual(vm.run.stage, 1)
    }

    func testRetrySameDeckReplaysTheSameCards() async {
        var r = GameEngine.newRun(seed: 4242, lv: 1)
        r.picks = 1
        r.shield = 0
        r.adUsed = true
        r.pair = [boomCard(), boomCard()]
        let vm = makeVM(store: store(with: r, unlock: 1))
        let firstDeal = GameEngine.newRun(seed: 4242, lv: 1).pair
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .result)
        vm.retrySameDeck()
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.seed, 4242)
        XCTAssertEqual(vm.run.lv, 1)
        XCTAssertEqual(vm.run.pair, firstDeal)
        XCTAssertEqual(vm.run.stage, 1)
        XCTAssertEqual(vm.run.marks, [])
        XCTAssertTrue(vm.canInteract)
    }

    func testNewRunKeepsLevelButChangesDeck() async {
        var r = GameEngine.newRun(seed: 4242, lv: 2)
        r.picks = 1
        r.shield = 0
        r.adUsed = true
        r.pair = [boomCard(), boomCard()]
        let vm = makeVM(store: store(with: r, unlock: 2))
        vm.pick(0)
        await vm.waitUntilSettled()
        vm.startNewRun()
        XCTAssertEqual(vm.run.seed, 777)
        XCTAssertEqual(vm.run.lv, 2)
    }

    func testNextLevelButtonStartsThatLevel() async {
        let vm = await banked(ready(stage: 6, lv: 0), unlock: 0)
        XCTAssertEqual(vm.unlock, 1)
        vm.startLevel(1)
        XCTAssertEqual(vm.run.lv, 1)
        XCTAssertEqual(vm.run.stage, 1)
        XCTAssertEqual(vm.lastLevel, 1)
    }
}
