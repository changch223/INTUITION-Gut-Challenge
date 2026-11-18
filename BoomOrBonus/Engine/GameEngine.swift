//
//  GameEngine.swift
//  BoomOrBonus
//
//  Pure rules. Line-by-line port of docs/redesign/reference/core.js.
//  No globals, no system randomness, no Date().
//

import Foundation

enum GameEngine {

    // MARK: - Targets

    static func nice(_ x: Double) -> Int {
        if x < 100 { return Int(Rules.jsRound(x)) }
        // Endless targets grow 1.25x per stage and would trap Int(Double) around stage 176.
        if !(x < Double(Rules.SCORE_CAP)) { return Rules.SCORE_CAP }
        let p = pow(10.0, floor(log10(x)) - 1)
        return Rules.clampScore(Rules.jsRound(x / p) * p)
    }

    static func targetAt(stage: Int, lv: Int) -> Int {
        let t = stage <= Rules.STAGES
            ? Rules.TGT[stage - 1]
            : Rules.TGT[Rules.STAGES - 1] * pow(Rules.EG, Double(stage - Rules.STAGES))
        return nice(t * (lv >= 1 ? 1.15 : 1))
    }

    static func targetOf(_ run: RunState, stage: Int) -> Int {
        nice(Double(targetAt(stage: stage, lv: run.lv)) * run.targetMul)
    }

    static func target(_ run: RunState) -> Int { targetOf(run, stage: run.stage) }

    static func stretch(_ run: RunState) -> Int { nice(Double(target(run)) * Rules.STR) }

    // MARK: - Boss / mod

    static func bossOf(stage: Int) -> BossID? {
        if stage % 2 != 0 { return nil }
        if stage <= Rules.STAGES { return Rules.bossStages6[stage / 2 - 1] }
        return Rules.bossStagesEndless[(stage / 2 - 4) % 4]
    }

    static func modAt(seed: UInt32, stage: Int) -> ModID? {
        if bossOf(stage: stage) != nil { return nil }
        let all = ModID.allCases
        return all[Int(seedOf(Int(seed), stage, 99)) % all.count]
    }

    static func modOf(_ run: RunState) -> ModID? { modAt(seed: run.seed, stage: run.stage) }

    // MARK: - Picks

    static func maxPicks(_ run: RunState) -> Int {
        max(1, Rules.PICKS + run.level(.hand) - (run.lv >= 2 ? 1 : 0))
    }

    static func stagePicks(_ run: RunState) -> Int {
        max(1, maxPicks(run)
            - (bossOf(stage: run.stage) == .short ? 2 : 0)
            - (modOf(run) == .lean ? 1 : 0))
    }

    static func price(_ run: RunState, _ n: Int) -> Int { n + (run.lv >= 5 ? 1 : 0) }

    static func canClear(_ run: RunState) -> Bool {
        run.value >= target(run) && run.picks < run.stagePicksAtStart
    }

    // MARK: - New run

    static func newRun(seed: UInt32, lv: Int = 0, mode: Mode = .free, targetMul: Double = 1) -> RunState {
        var run = RunState(
            seed: seed, lv: lv, targetMul: targetMul, mode: mode,
            shield: lv >= 3 ? 0 : 1,
            inventory: lv >= 3 ? Inventory(peek: 0, roll: 0, dbl: 0) : Inventory(peek: 1, roll: 1, dbl: 0)
        )
        run.picks = stagePicks(run)
        run.stagePicksAtStart = run.picks
        run.pair = genPair(run)
        return run
    }

    // MARK: - Cards

    static func smult(_ run: RunState) -> Double {
        min(1 + (modOf(run) == .heat ? 0.5 : 0.25) * Double(run.streak), run.has(.hot) ? 3 : 2)
    }

    static func genPair(_ run: RunState) -> [Card] {
        var r = Mulberry32(seedOf(Int(run.seed), run.stage, run.idx, run.rerolls))
        let md = modOf(run)
        let top = md == .calm ? 3 : 4
        let d1 = 1 + Int(floor(r.next() * Double(top)))
        var d2 = 1 + Int(floor(r.next() * Double(top - 1)))
        if d2 >= d1 { d2 += 1 }
        let sc = (1 + 0.3 * Double(run.stage - 1)) * (1 + 0.25 * Double(run.level(.add)))
        let bs = bossOf(stage: run.stage)
        let dp = (run.lv >= 4 ? 0.05 : 0) + (bs == .shaky ? 0.1 : 0) + (md == .fuse ? 0.08 : 0)

        func mk(_ d: Int) -> Card {
            let u = r.next(), tm = r.next(), b = r.next()
            var p = Rules.jsRound((Rules.P[d - 1] + dp) * 100) / 100
            if d == 1 && run.has(.cool) { p = 0 }
            var op: CardOp
            var n: Double
            if tm < (md == .wild ? 0.56 : 0.28) && d > 1 && run.value >= 4 {
                op = .mul
                n = Rules.MUL[d - 1] + 0.5 * Double(run.level(.snow))
                if d == 4 && run.has(.gamb) { n *= 1.5 }
            } else {
                op = .add
                let raw = Rules.ADD[d - 1] * sc * (0.75 + 0.6 * u)
                    * (md == .fuse ? 1.4 : 1)
                    * (md == .small && d == 1 ? 2 : 1)
                n = max(1, Rules.jsRound(raw))
                if d == 4 && run.has(.gamb) { n = Rules.jsRound(n * 1.5) }
            }
            return Card(danger: d, p: p, op: op, n: n, boom: b < p)
        }

        var a = mk(d1)
        var b = mk(d2)
        let f = r.next() < 0.5 ? 0 : 1
        if bs == .fog {
            if f == 0 { a.fog = true } else { b.fog = true }
        }
        return [a, b]
    }

    static func deltaOf(_ run: RunState, _ c: Card) -> Int {
        let base = c.op == .add ? c.n : Double(run.value) * (c.n - 1)
        return Rules.clampScore(Rules.jsRound(base * smult(run) * (run.doubleArmed ? 2 : 1)))
    }

    @discardableResult
    static func pickCard(_ run: inout RunState, index i: Int) -> PickEvent {
        let c = run.pair[i]
        let ev: PickEvent
        if c.boom {
            if run.has(.defuse) && !run.defusedThisStage {
                run.defusedThisStage = true
                ev = .defuse
            } else if run.shield > 0 {
                run.shield -= 1
                ev = .shield
            } else {
                let s0 = run.streak
                run.streak = run.has(.grit) ? Int((Double(s0) / 2).rounded(.up)) : 0
                var lost = 0
                if bossOf(stage: run.stage) == .crush {
                    lost = run.value / 2
                    run.value -= lost
                }
                run.picks -= 1
                ev = .boom(lost: lost, s0: s0, s1: run.streak)
            }
        } else {
            let d = deltaOf(run, c)
            run.value = Rules.saturatingScore(run.value, d)
            run.streak += 1
            run.picks -= 1
            if modOf(run) == .gold {
                run.coins += 1  // coinsEarned counts stage-clear rewards only (03 §4.2)
            }
            ev = .safe(delta: d)
        }
        run.doubleArmed = false
        run.peekArmed = false
        run.idx += 1
        run.rerolls = 0
        return ev
    }

    // MARK: - Rewards / stage flow

    static func rewardParts(_ run: RunState) -> [RewardPart] {
        let md = modOf(run)
        var a = [
            RewardPart(kind: .base, amount: (run.lv >= 5 ? 2 : 3) + (md == .lean ? 3 : 0)),
            RewardPart(kind: .picksLeft, amount: run.picks * (md == .rich ? 2 : 1)),
        ]
        if run.value >= stretch(run) { a.append(RewardPart(kind: .stretch, amount: 3)) }
        if run.has(.bank) {
            // Interest uses coins BEFORE the reward is added.
            let x = min(3, run.coins / 5)
            if x > 0 { a.append(RewardPart(kind: .interest, amount: x)) }
        }
        return a
    }

    static func reward(_ run: RunState) -> Int {
        rewardParts(run).reduce(0) { $0 + $1.amount }
    }

    @discardableResult
    static func clearStage(_ run: inout RunState) -> Int {
        run.lastRewardParts = rewardParts(run)
        let rw = reward(run)
        run.marks.append(run.value >= stretch(run) ? 2 : 1)
        run.coins += rw
        run.coinsEarned += rw
        run.total = Rules.saturatingAdd(run.total, run.value)
        run.phase = (!run.endless && run.stage >= Rules.STAGES) ? .win : .shop
        return rw
    }

    static func failStage(_ run: inout RunState) {
        run.marks.append(0)
        run.total = Rules.saturatingAdd(run.total, run.value)
        run.phase = .over
    }

    static func nextStage(_ run: inout RunState) {
        run.stage += 1
        run.value = 0
        run.picks = stagePicks(run)
        run.stagePicksAtStart = run.picks
        run.idx = 0
        run.rerolls = 0
        run.shopRerolls = 0
        run.defusedThisStage = false
        run.doubleArmed = false
        run.peekArmed = false
        if run.has(.eye) { run.inventory.peek += 1 }
        run.phase = .play
        run.pair = genPair(run)
    }

    /// Rewarded-ad revive: picks = 2 (not +2), once per run, fresh pair.
    static func reviveWithAd(_ run: inout RunState) {
        run.adUsed = true
        run.picks = 2
        run.pair = genPair(run)
    }
}
