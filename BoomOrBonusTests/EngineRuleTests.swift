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

    // MARK: - Overflow safety (Phase 3: long endless runs)

    func testNiceDoesNotTrapAndIsUnchangedBelowTheCap() {
        // Below the old trap point nothing changes: 240 * 1.25^170 is about 1e19 > Int.max, 1.25^100 is fine.
        XCTAssertEqual(GameEngine.nice(145), 150)
        XCTAssertEqual(GameEngine.nice(240 * pow(1.25, 20)), GameEngine.targetAt(stage: 26, lv: 0))
        for stage in [100, 150, 170, 175, 176, 177, 178, 179, 180, 200, 5000] {
            let t = GameEngine.targetAt(stage: stage, lv: 5)
            XCTAssertGreaterThan(t, 0, "stage \(stage)")
            XCTAssertLessThanOrEqual(t, Rules.SCORE_CAP)
        }
        XCTAssertEqual(GameEngine.nice(.infinity), Rules.SCORE_CAP)
        XCTAssertEqual(GameEngine.nice(.nan), Rules.SCORE_CAP)
        XCTAssertEqual(GameEngine.nice(1e300), Rules.SCORE_CAP)
        XCTAssertEqual(GameEngine.nice(9.4e17), 940_000_000_000_000_000)
        // Targets keep growing until the cap, never decrease.
        var last = 0
        for stage in 1...400 {
            let t = GameEngine.targetAt(stage: stage, lv: 0)
            XCTAssertGreaterThanOrEqual(t, last)
            last = t
        }
    }

    func testDeltaAndValueAndTotalSaturateInsteadOfTrapping() {
        var r = makeRun()
        r.endless = true
        r.blessings = [.snow: 40, .hot: 1, .add: 40]
        r.streak = 100
        r.doubleArmed = true
        r.value = Rules.SCORE_CAP - 5
        let mul = Card(danger: 4, p: 0, op: .mul, n: 1e6, boom: false)
        XCTAssertEqual(GameEngine.deltaOf(r, mul), Rules.SCORE_CAP)
        r.pair = [mul, mul]
        _ = GameEngine.pickCard(&r, index: 0)
        XCTAssertEqual(r.value, Rules.SCORE_CAP, "value is held at the cap")
        // Total near Int.max.
        r.total = Int.max - 10
        r.phase = .play
        r.picks = r.stagePicksAtStart - 1
        GameEngine.clearStage(&r)
        XCTAssertEqual(r.total, Int.max)
        r.total = Int.min + 10
        r.value = -Rules.SCORE_CAP
        GameEngine.failStage(&r)
        XCTAssertGreaterThanOrEqual(r.total, Int.min)
    }

    func testEndlessRunToStage200DoesNotCrash() {
        var r = GameEngine.newRun(seed: 20261116, lv: 5)
        r.blessings = [.snow: 5, .add: 5, .hand: 3, .hot: 1, .gamb: 1, .bank: 1, .eye: 1]
        r.endless = true
        r.coins = 50
        var maxTarget = 0
        for stage in 1...200 {
            XCTAssertEqual(r.stage, stage)
            XCTAssertEqual(r.pair.count, 2)
            let target = GameEngine.target(r)
            XCTAssertGreaterThan(target, 0)
            XCTAssertLessThanOrEqual(GameEngine.stretch(r), Rules.SCORE_CAP)
            XCTAssertGreaterThanOrEqual(target, maxTarget)
            maxTarget = target
            // A few real picks (multiplier cards compound the score), then bank the stage.
            r.streak = 30
            r.doubleArmed = true
            for _ in 0..<3 where r.picks > 1 {
                let i = r.pair[0].op == .mul ? 0 : 1
                _ = GameEngine.pickCard(&r, index: i)
                r.pair = GameEngine.genPair(r)
            }
            r.value = max(r.value, target)       // reaching the target is not the point here
            r.picks = min(r.picks, max(0, r.stagePicksAtStart - 1))
            GameEngine.clearStage(&r)
            XCTAssertEqual(r.phase, .shop)
            XCTAssertNoThrow(Shop.shopOffer(r))
            GameEngine.nextStage(&r)
        }
        XCTAssertEqual(r.stage, 201)
        XCTAssertGreaterThan(r.total, 0)
    }
}
