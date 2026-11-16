//
//  EngineRuleTests.swift
//  BoomOrBonusTests
//

import XCTest
@testable import BoomOrBonus

final class EngineRuleTests: XCTestCase {

    /// Stage 1 with the neutral "heat" rule (only changes streak bonus), no boss.
    private func makeRun(lv: Int = 0) -> RunState {
        GameEngine.newRun(seed: seedWithStage1Mod(.heat), lv: lv, mode: .free)
    }

    func testShieldBlocksWithoutLosingPickOrStreak() {
        var r = makeRun()
        r.streak = 3
        r.pair = [boomCard(), safeCard()]
        XCTAssertEqual(r.shield, 1)
        let picks = r.picks
        let ev = GameEngine.pickCard(&r, index: 0)
        XCTAssertEqual(ev, .shield)
        XCTAssertEqual(r.picks, picks)
        XCTAssertEqual(r.streak, 3)
        XCTAssertEqual(r.shield, 0)
        XCTAssertEqual(r.idx, 1)
    }

    func testDefuseWorksOncePerStage() {
        var r = makeRun()
        r.shield = 0
        r.blessings[.defuse] = 1
        r.streak = 2
        r.pair = [boomCard(), boomCard()]
        let picks = r.picks
        XCTAssertEqual(GameEngine.pickCard(&r, index: 0), .defuse)
        XCTAssertEqual(r.picks, picks)
        XCTAssertEqual(r.streak, 2)
        // Second boom in the same stage is a real boom.
        if case .boom = GameEngine.pickCard(&r, index: 1) {} else { XCTFail("expected boom") }
        XCTAssertEqual(r.picks, picks - 1)
        // New stage resets defuse.
        GameEngine.nextStage(&r)
        r.pair = [boomCard(), boomCard()]
        XCTAssertEqual(GameEngine.pickCard(&r, index: 0), .defuse)
    }

    func testGritHalvesStreakRoundingUp() {
        for (s0, s1) in [(1, 1), (4, 2), (5, 3)] {
            var r = makeRun()
            r.shield = 0
            r.blessings[.grit] = 1
            r.streak = s0
            r.pair = [boomCard(), safeCard()]
            XCTAssertEqual(GameEngine.pickCard(&r, index: 0), .boom(lost: 0, s0: s0, s1: s1))
            XCTAssertEqual(r.streak, s1)
        }
        // Without grit, streak resets.
        var r = makeRun()
        r.shield = 0
        r.streak = 5
        r.pair = [boomCard(), safeCard()]
        GameEngine.pickCard(&r, index: 0)
        XCTAssertEqual(r.streak, 0)
    }

    func testCrushHalvesOnlyStageValueAndNotTotal() {
        var r = makeRun()
        r.stage = 6
        XCTAssertEqual(GameEngine.bossOf(stage: 6), .crush)
        r.shield = 0
        r.value = 11
        r.total = 50
        r.pair = [boomCard(), safeCard()]
        let ev = GameEngine.pickCard(&r, index: 0)
        XCTAssertEqual(ev, .boom(lost: 5, s0: 0, s1: 0))
        XCTAssertEqual(r.value, 6)
        XCTAssertEqual(r.total, 50)

        // Blocked boom does not crush.
        var r2 = makeRun()
        r2.stage = 6
        r2.shield = 1
        r2.value = 11
        r2.pair = [boomCard(), safeCard()]
        XCTAssertEqual(GameEngine.pickCard(&r2, index: 0), .shield)
        XCTAssertEqual(r2.value, 11)
    }

    func testCannotClearWithoutAPick() {
        var r = makeRun()
        r.value = GameEngine.target(r)
        XCTAssertEqual(r.picks, r.stagePicksAtStart)
        XCTAssertFalse(GameEngine.canClear(r))
        r.pair = [safeCard(n: 1), safeCard(n: 1)]
        GameEngine.pickCard(&r, index: 0)
        XCTAssertTrue(GameEngine.canClear(r))
        r.value = GameEngine.target(r) - 1
        XCTAssertFalse(GameEngine.canClear(r))
    }

    func testInterestUsesCoinsBeforeReward() {
        var r = makeRun()
        r.blessings[.bank] = 1
        r.coins = 9            // before: floor(9/5) = 1; after a >=3 reward it would be 2
        r.picks = 3
        r.value = 1
        let parts = GameEngine.rewardParts(r)
        XCTAssertEqual(parts.first { $0.kind == .interest }?.amount, 1)
        let rw = GameEngine.clearStage(&r)
        XCTAssertEqual(rw, 3 + 3 + 1)
        XCTAssertEqual(r.coins, 9 + rw)
        // Capped at 3.
        r.coins = 100
        XCTAssertEqual(GameEngine.rewardParts(r).first { $0.kind == .interest }?.amount, 3)
    }

    func testStage6ClearIsWinUnlessEndless() {
        var r = makeRun()
        r.stage = 6
        r.value = GameEngine.target(r)
        r.picks = 2
        GameEngine.clearStage(&r)
        XCTAssertEqual(r.phase, .win)

        var e = makeRun()
        e.stage = 6
        e.endless = true
        e.value = GameEngine.target(e)
        e.picks = 2
        GameEngine.clearStage(&e)
        XCTAssertEqual(e.phase, .shop)

        var n = makeRun()
        n.value = 999
        GameEngine.clearStage(&n)
        XCTAssertEqual(n.phase, .shop)
    }

    func testStreakCarriesAcrossStages() {
        var r = makeRun()
        r.streak = 5
        r.value = 30
        GameEngine.nextStage(&r)
        XCTAssertEqual(r.stage, 2)
        XCTAssertEqual(r.streak, 5)
        XCTAssertEqual(r.value, 0)
        XCTAssertEqual(r.idx, 0)
        XCTAssertEqual(r.picks, r.stagePicksAtStart)
        XCTAssertEqual(r.phase, .play)
        XCTAssertEqual(r.pair.count, 2)
    }

    func testBlessingCapAndStacking() {
        var r = makeRun()
        r.coins = 100
        for b in [BlessingID.add, .cool, .gamb, .grit, .bank] {
            XCTAssertTrue(Shop.buyBlessing(&r, b))
        }
        XCTAssertEqual(r.blessings.count, 5)
        // Sixth distinct blessing refused, coins untouched.
        let coins = r.coins
        XCTAssertFalse(Shop.buyBlessing(&r, .eye))
        XCTAssertEqual(r.coins, coins)
        // Non-stackable repeat refused.
        XCTAssertFalse(Shop.buyBlessing(&r, .cool))
        // Stackable owned one stacks without a new slot.
        XCTAssertTrue(Shop.buyBlessing(&r, .add))
        XCTAssertEqual(r.level(.add), 2)
        XCTAssertEqual(r.blessings.count, 5)
        // Shop pool when full contains only owned stackables.
        XCTAssertEqual(Shop.shopOffer(r), [.add])
    }

    func testLegendDifficultyPriceAndReward() {
        var r = makeRun(lv: 5)
        XCTAssertEqual(GameEngine.price(r, 4), 5)
        XCTAssertEqual(GameEngine.price(makeRun(lv: 4), 4), 4)
        r.coins = 4
        XCTAssertFalse(Shop.buyItem(&r, .shield))
        r.coins = 5
        XCTAssertTrue(Shop.buyItem(&r, .shield))
        XCTAssertEqual(r.coins, 0)
        r.picks = 0
        r.value = 0
        let parts = GameEngine.rewardParts(r)
        XCTAssertEqual(parts.first?.kind, .base)
        XCTAssertEqual(parts.first?.amount, 2)
        XCTAssertEqual(GameEngine.reward(makeRun(lv: 4)), 3 + 6)  // lv>=2 has 6 picks
    }

    func testReviveWithAdSetsTwoPicks() {
        var r = makeRun()
        r.picks = 0
        GameEngine.reviveWithAd(&r)
        XCTAssertEqual(r.picks, 2)
        XCTAssertTrue(r.adUsed)
    }

    func testRunStateCodableRoundTrip() throws {
        var r = makeRun()
        r.blessings[.grit] = 1
        r.blessings[.add] = 2
        let data = try JSONEncoder().encode(r)
        XCTAssertEqual(try JSONDecoder().decode(RunState.self, from: data), r)
    }
}
