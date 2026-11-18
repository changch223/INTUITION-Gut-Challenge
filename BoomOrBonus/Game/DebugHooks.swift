//
//  DebugHooks.swift
//  BoomOrBonus
//
//  QA launch arguments that put a run into a given state. They only apply together with `-seed <n>`,
//  and `parse` returns an empty set outside Debug builds, so nothing here can reach a release build.
//  `-seed` runs use a separate save file (save-qa.json, wiped at launch; see SaveStore.shared).
//  `-qaSave` (no `-seed`) relaunches from that file unchanged, e.g. to test kill / restore.
//
//    -lv N              difficulty of the new run (0...5)
//    -unlock N          highest unlocked difficulty (0...5); default 0 with -seed
//    -stage N           start the run at stage N (earlier stages are marked cleared)
//    -blessings a,b,a   blessings to own, repeats stack (add snow cool gamb hot grit hand eye bank defuse)
//    -coins N  -streak N  -picks N  -value N  -shield N  -peeks N
//    -endless           the run is already in endless mode
//    -boomPair          the first pair is two bombs (to see shield / defuse / grit / crush)
//    -shop              the stage is cleared: opens the shop (or the win result at stage 6)
//    -fail              the stage is failed: opens the result sheet
//

import Foundation

struct DebugHooks: Equatable {
    var lv: Int?
    var unlock: Int?
    var stage: Int?
    var blessings: [BlessingID] = []
    var coins: Int?
    var streak: Int?
    var picks: Int?
    var value: Int?
    var shield: Int?
    var peeks: Int?
    var endless = false
    var boomPair = false
    var shop = false
    var fail = false

    static func parse(arguments: [String] = ProcessInfo.processInfo.arguments) -> DebugHooks {
        #if DEBUG
        func int(_ key: String) -> Int? {
            guard let i = arguments.firstIndex(of: key), i + 1 < arguments.count else { return nil }
            return Int(arguments[i + 1])
        }
        var h = DebugHooks()
        h.lv = int("-lv").map { min(5, max(0, $0)) }
        h.unlock = int("-unlock")
        h.stage = int("-stage").map { max(1, $0) }
        h.coins = int("-coins")
        h.streak = int("-streak")
        h.picks = int("-picks")
        h.value = int("-value")
        h.shield = int("-shield")
        h.peeks = int("-peeks")
        h.endless = arguments.contains("-endless")
        h.boomPair = arguments.contains("-boomPair")
        h.shop = arguments.contains("-shop")
        h.fail = arguments.contains("-fail")
        if let i = arguments.firstIndex(of: "-blessings"), i + 1 < arguments.count {
            h.blessings = arguments[i + 1].split(separator: ",").compactMap { BlessingID(rawValue: String($0)) }
        }
        return h
        #else
        return DebugHooks()
        #endif
    }

    /// Applies the hooks to a fresh run (already dealt for stage 1).
    func apply(to run: inout RunState) {
        if endless { run.endless = true }
        if let stage {
            run.stage = stage
            run.marks = Array(repeating: 1, count: stage - 1)
        }
        for b in blessings { run.blessings[b, default: 0] += 1 }
        if let coins { run.coins = coins }
        if let streak { run.streak = streak }
        if let shield { run.shield = shield }
        if let peeks { run.inventory.peek = peeks }
        run.value = value ?? 0
        run.picks = GameEngine.stagePicks(run)
        run.stagePicksAtStart = run.picks
        if let picks { run.picks = picks }
        run.pair = GameEngine.genPair(run)
        if boomPair {
            run.pair = [
                Card(danger: 2, p: 1, op: .add, n: 5, boom: true),
                Card(danger: 3, p: 1, op: .add, n: 7, boom: true),
            ]
            if GameEngine.bossOf(stage: run.stage) == .fog { run.pair[0].fog = true }
        }
        if shop || fail {
            if fail {
                GameEngine.failStage(&run)
            } else {
                run.value = max(run.value, GameEngine.target(run))
                run.picks = min(run.picks, max(0, run.stagePicksAtStart - 2))
                GameEngine.clearStage(&run)
            }
        }
    }
}
