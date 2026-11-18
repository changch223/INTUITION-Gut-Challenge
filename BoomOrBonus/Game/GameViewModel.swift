//
//  GameViewModel.swift
//  BoomOrBonus
//
//  Owns the RunState and drives one pick end to end (02-screens-ux.md §3):
//  lock -> fuse ticks -> reveal -> 800ms -> next pair / stage end.
//  The engine does not check phase, index or empty pairs, so every engine call is guarded here.
//  All delays go through `sleeper` so tests can run instantly.
//

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class GameViewModel {

    typealias Sleeper = @Sendable (Double) async -> Void

    /// Seconds. Defaults are the exact values from 02 §3.
    struct Timing {
        var tickGap = 0.115        // between fuse ticks
        var reveal = 0.14          // after the last tick
        var deal = 0.8             // reveal -> next pair / stage end
        var clearToSheet = 0.75    // 04 §4: clear -> panel
        var winToSheet = 0.95
        var ad = 2.5               // mocked rewarded ad
        var toast = 1.8

        static let standard = Timing()

        /// Reduce Motion (02 §3): reveal 40ms, deal 260ms, no tick gap.
        var reduced: Timing {
            var t = self
            t.tickGap = 0
            t.reveal = min(reveal, 0.04)
            t.deal = min(deal, 0.26)
            return t
        }
    }

    /// What a card shows. Frozen while a pick is resolving so the card does not change under the player.
    struct CardFace: Equatable {
        var card: Card
        var preview: Int       // "成功 → N", already includes streak and double
        var peek: Bool
    }

    enum Reveal: Equatable {
        case safe(delta: Int)
        case boom(lost: Int)
        case shield
        case defuse
    }

    enum Sheet: Equatable {
        case fail
        case shop
        case difficulty
        case result
    }

    struct Toast: Equatable, Identifiable {
        let id: Int
        let text: String
    }

    // MARK: - State

    private(set) var run: RunState
    private(set) var faces: [CardFace] = []
    private(set) var pickedIndex: Int?
    private(set) var reveal: Reveal?
    private(set) var isLocked = false
    private(set) var sheet: Sheet?
    private(set) var adPlaying = false
    private(set) var toast: Toast?
    private(set) var dealID = 0
    private(set) var shakeCount = 0
    /// Mirrors of SaveData so views observe them (SaveStore itself is not observable).
    private(set) var unlock = 0
    private(set) var lastLevel = 0
    private(set) var deepest = 0
    /// Where 「取消」 in the difficulty sheet goes back to (the result sheet, or nothing).
    private(set) var difficultyReturn: Sheet?

    /// Flat price of 「換一批」 at every difficulty (01 §11).
    static let rerollCost = 1
    /// After a shop purchase / reroll, further shop taps are ignored for this long (double-tap guard).
    static let shopLockSeconds = 0.25

    /// The task for whatever flow is in progress (pick, clear, ad, ...). Tests await it.
    @ObservationIgnored private(set) var flowTask: Task<Void, Never>?
    @ObservationIgnored private(set) var shopLockTask: Task<Void, Never>?
    @ObservationIgnored private var shopBusy = false
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var toastCounter = 0

    @ObservationIgnored private let store: SaveStore
    @ObservationIgnored private let timing: Timing
    @ObservationIgnored private let sleeper: Sleeper
    @ObservationIgnored private let reduceMotion: @MainActor () -> Bool
    @ObservationIgnored private var sound: SoundPlayer?
    @ObservationIgnored private let feedbackEnabled: Bool
    @ObservationIgnored private let randomSeed: () -> UInt32
    @ObservationIgnored private let hooks: DebugHooks

    // MARK: - Setup

    /// One shared instance for the app, so a re-created GameScreen never re-runs init side effects.
    static let live = GameViewModel(store: .shared, launchSeed: debugLaunchSeed(), hooks: DebugHooks.parse())

    /// - Parameter launchSeed: starts a new free run with this seed and ignores any save (QA hook).
    ///   It also resets unlock / lastLevel / deepest so every launch starts from the same state.
    /// - Parameter hooks: Debug-only launch arguments (`-stage`, `-blessings`, ...), only used with `launchSeed`.
    init(
        store: SaveStore,
        launchSeed: UInt32? = nil,
        hooks: DebugHooks = DebugHooks(),
        timing: Timing = .standard,
        sleeper: @escaping Sleeper = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        },
        reduceMotion: (@MainActor () -> Bool)? = nil,
        feedbackEnabled: Bool = true,
        randomSeed: @escaping () -> UInt32 = { UInt32.random(in: 0..<2147483647) }
    ) {
        self.store = store
        self.timing = timing
        self.sleeper = sleeper
        self.reduceMotion = reduceMotion ?? { UIAccessibility.isReduceMotionEnabled }
        self.feedbackEnabled = feedbackEnabled
        self.randomSeed = randomSeed
        self.hooks = hooks
        if feedbackEnabled { self.sound = SoundPlayer(isMuted: { [store] in store.data.muted }) }

        var needsSave = false
        let initial: RunState
        if let launchSeed {
            store.update {
                $0.unlock = min(5, max(0, hooks.unlock ?? 0))
                $0.lastLevel = 0
                $0.deepest = 0
            }
            var r = Self.freshRun(seed: launchSeed, lv: hooks.lv ?? 0)
            hooks.apply(to: &r)
            initial = r
            needsSave = true
        } else if let restored = store.restorableFreeRun() {
            initial = restored
        } else {
            initial = Self.freshRun(seed: randomSeed(), lv: Self.startLevel(store.data))
            needsSave = true
        }
        self.run = initial
        self.faces = makeFaces()
        syncFromStore()

        // Resume where the player left off.
        switch run.phase {
        case .shop:
            // 03 §2.1: reopen the shop; the same shelf comes back from the save.
            if run.shopOffer.isEmpty { run.shopOffer = Shop.shopOffer(run); needsSave = true }
            isLocked = true
            sheet = .shop
        case .win:
            // Only reachable through the debug hooks (a saved win is not restored).
            settleClear()
            needsSave = true
            isLocked = true
            sheet = .result
        case .over:
            isLocked = true
            sheet = .result
        case .play:
            if run.picks <= 0 {
                // Killed between the last pick and the stage-end resolution.
                isLocked = true
                flowTask = Task { await self.resolveStageEnd() }
            }
        }
        if needsSave { save() }
    }

    /// 03 §2.2: a new free run starts at min(lastLevel, unlock).
    static func startLevel(_ data: SaveData) -> Int { min(data.lastLevel, data.unlock) }

    private func syncFromStore() {
        unlock = store.data.unlock
        lastLevel = store.data.lastLevel
        deepest = store.data.deepest
    }

    /// `-seed <UInt32>` on the command line (Debug builds only).
    static func debugLaunchSeed(arguments: [String] = ProcessInfo.processInfo.arguments) -> UInt32? {
        #if DEBUG
        guard let i = arguments.firstIndex(of: "-seed"), i + 1 < arguments.count else { return nil }
        return UInt32(arguments[i + 1])
        #else
        return nil
        #endif
    }

    private static func freshRun(seed: UInt32, lv: Int) -> RunState {
        GameEngine.newRun(seed: seed, lv: lv, mode: .free)
    }

    // MARK: - Derived

    var target: Int { GameEngine.target(run) }
    var stretch: Int { GameEngine.stretch(run) }
    var adDuration: Double { timing.ad }
    var canClear: Bool { GameEngine.canClear(run) }
    var reward: Int { GameEngine.reward(run) }
    var isFirstPick: Bool { run.picks == run.stagePicksAtStart }
    var smult: Double { GameEngine.smult(run) }
    var boss: BossID? { GameEngine.bossOf(stage: run.stage) }
    var mod: ModID? { GameEngine.modOf(run) }

    /// Taps on cards, items and the bank button only work while this is true.
    var canInteract: Bool {
        !isLocked && sheet == nil && !adPlaying && run.phase == .play && run.picks > 0
    }

    private var reduced: Bool { reduceMotion() }
    private var effectiveTiming: Timing { reduced ? timing.reduced : timing }

    // MARK: - Pick flow

    func pick(_ i: Int) {
        guard canInteract, run.pair.count == 2, run.pair.indices.contains(i), faces.count == 2 else { return }
        isLocked = true            // synchronous: a second tap in the same run loop sees this
        pickedIndex = i
        reveal = nil
        flowTask = Task { await self.runPick(i) }
    }

    private func runPick(_ i: Int) async {
        let t = effectiveTiming
        let dealt = run.pair[i]
        // 02 §3: d+1 ticks. (Fog cards tick the same way, as in prototype.html.)
        let steps = dealt.danger + 1
        for s in 0..<steps {
            playTick(s)
            if t.tickGap > 0 { await sleeper(t.tickGap) }
        }
        await sleeper(t.reveal)

        // Stale-state guard: the pair must still be the one the player tapped.
        guard !Task.isCancelled, run.phase == .play, run.picks > 0,
              run.pair.indices.contains(i), run.pair[i] == dealt else {
            pickedIndex = nil
            isLocked = false
            return
        }

        let v0 = run.value
        let tgt = GameEngine.target(run)
        let first = isFirstPick
        let ev = GameEngine.pickCard(&run, index: i)

        switch ev {
        case .safe(let delta):
            reveal = .safe(delta: delta)
            playSound("ButtonSuccess")
            haptic { HapticManager.shared.playSuccess() }
            if (v0 < tgt || first) && run.value >= tgt && run.picks > 0 {
                showToast(String(localized: "達標！可以過關，也可以拚超標 \(Fmt.int(GameEngine.stretch(run)))"), seconds: 2.4)
            }
        case .boom(let lost, let s0, let s1):
            reveal = .boom(lost: lost)
            playSound("ButtonFail")
            haptic { HapticManager.shared.playError() }
            if !reduced { shakeCount += 1 }
            if run.has(.grit) && s0 > 0 {
                showToast(String(localized: "不屈發動：連中 \(s0) → \(s1)，得分仍 ×\(Fmt.num(GameEngine.smult(run)))（沒有不屈會歸零）"), seconds: 3)
            } else {
                var text = String(localized: "爆了：扣 1 手")
                if lost > 0 { text += String(localized: "、分數減半") }
                if s0 > 0 { text += String(localized: "，連中 \(s0) 歸零") }
                showToast(text, seconds: 2.2)
            }
        case .shield:
            reveal = .shield
            playSound("Click")
            haptic { HapticManager.shared.playClick() }
            showToast(String(localized: "保命符擋下爆炸：這手不算、不扣手數，連中保留（剩 \(run.shield) 張）"), seconds: 2.8)
        case .defuse:
            reveal = .defuse
            playSound("Click")
            haptic { HapticManager.shared.playClick() }
            showToast(String(localized: "拆彈：這關第一次爆炸無效，不扣手數"), seconds: 2.8)
        }

        // Deal the next pair now (engine genPair after pickCard, as core.js / prototype.html),
        // so the save is consistent. The screen keeps showing the old faces until the deal delay ends.
        if run.picks > 0 { run.pair = GameEngine.genPair(run) }
        save()

        await sleeper(t.deal)
        guard !Task.isCancelled else { return }

        if run.picks <= 0 {
            await resolveStageEnd()
        } else {
            dealFaces()
            isLocked = false
        }
    }

    private func dealFaces() {
        pickedIndex = nil
        reveal = nil
        faces = makeFaces()
        dealID += 1
    }

    private func makeFaces() -> [CardFace] {
        run.pair.map { CardFace(card: $0, preview: run.value + GameEngine.deltaOf(run, $0), peek: run.peekArmed) }
    }

    // MARK: - Stage end

    /// Picks ran out: clear automatically if the target is met, otherwise fail.
    private func resolveStageEnd() async {
        guard run.phase == .play else {
            isLocked = false
            return
        }
        if GameEngine.canClear(run) {
            await performClear()
        } else {
            playSound("ButtonFail")
            if !run.adUsed {
                sheet = .fail
            } else {
                GameEngine.failStage(&run)
                save()
                sheet = .result
            }
        }
    }

    /// The bank button.
    func bank() {
        guard canInteract, GameEngine.canClear(run) else { return }
        isLocked = true
        flowTask = Task { await self.performClear() }
    }

    private func performClear() async {
        guard run.phase == .play, GameEngine.canClear(run) else {
            isLocked = false
            return
        }
        isLocked = true
        GameEngine.clearStage(&run)
        settleClear()
        playSound("ButtonSuccess")
        haptic { HapticManager.shared.playSuccess() }
        save()
        let win = run.phase == .win
        await sleeper(win ? timing.winToSheet : timing.clearToSheet)
        guard !Task.isCancelled else { return }
        sheet = win ? .result : .shop
    }

    /// Everything that follows `clearStage`: deals the shop shelf, records `deepest` (endless),
    /// and unlocks the next difficulty when all of stages 1-6 are cleared (01 §13).
    private func settleClear() {
        if run.endless { recordDeepest() }
        switch run.phase {
        case .shop:
            run.shopOffer = Shop.shopOffer(run)
        case .win:
            let six = run.marks.prefix(Rules.STAGES)
            let cleared = six.count == Rules.STAGES && six.allSatisfy { $0 > 0 }
            if cleared && run.lv >= store.data.unlock && run.lv < Rules.difficulties.count - 1 {
                let next = run.lv + 1
                run.newlyUnlockedLevel = next
                store.update { $0.unlock = next }
                syncFromStore()
            }
        default:
            break
        }
    }

    /// `deepest` = number of stages cleared in an endless run (same as prototype `save.deep`).
    private func recordDeepest() {
        let cleared = run.marks.filter { $0 > 0 }.count
        if cleared > store.data.deepest {
            store.update { $0.deepest = cleared }
            syncFromStore()
        }
    }

    // MARK: - Shop (02 §4.1)

    var nextStageNumber: Int { run.stage + 1 }
    var nextTarget: Int { GameEngine.targetOf(run, stage: run.stage + 1) }
    var nextBoss: BossID? { GameEngine.bossOf(stage: run.stage + 1) }
    var nextMod: ModID? { GameEngine.modAt(seed: run.seed, stage: run.stage + 1) }

    func price(_ base: Int) -> Int { GameEngine.price(run, base) }

    var inShop: Bool { sheet == .shop && run.phase == .shop }

    func canBuy(_ id: BlessingID) -> Bool {
        let cost = price(id.basePrice)
        if run.coins < cost { return false }
        if run.has(id) { return id.stackable }
        return run.blessings.count < Rules.MAX_BLESSINGS
    }

    func canBuy(_ item: ItemID) -> Bool { run.coins >= price(item.basePrice) }

    var canReroll: Bool { run.coins >= Self.rerollCost }

    /// A tap on a blessing slot. The slot must be on the current shelf; the engine checks coins, cap and stacking.
    func buyBlessing(_ id: BlessingID) {
        guard inShop, !shopBusy, run.shopOffer.contains(where: { $0 == id }) else { return }
        guard Shop.buyBlessing(&run, id) else { return }
        afterShopAction()
    }

    func buyItem(_ item: ItemID) {
        guard inShop, !shopBusy else { return }
        guard Shop.buyItem(&run, item) else { return }
        afterShopAction()
    }

    /// 「換一批」: flat $1, `srr += 1`, new shelf from the seed.
    func rerollShop() {
        guard inShop, !shopBusy, canReroll else { return }
        run.coins -= Self.rerollCost
        run.shopRerolls += 1
        run.shopOffer = Shop.shopOffer(run)
        afterShopAction()
    }

    private func afterShopAction() {
        playSound("Click")
        haptic { HapticManager.shared.playClick() }
        save()
        // Tap lock for the shop: a double tap must not buy twice.
        shopBusy = true
        shopLockTask?.cancel()
        shopLockTask = Task {
            await self.sleeper(Self.shopLockSeconds)
            if !Task.isCancelled { self.shopBusy = false }
        }
    }

    /// 「前往第 N 關」
    func nextStage() {
        guard inShop else { return }
        GameEngine.nextStage(&run)
        run.shopOffer = []
        shopBusy = false
        shopLockTask?.cancel()
        sheet = nil
        save()
        dealFaces()
        isLocked = false
        var text = ""
        if let b = GameEngine.bossOf(stage: run.stage) {
            text = String(localized: "魔王「\(b.name)」：\(b.desc)")
        } else if let m = GameEngine.modOf(run) {
            text = String(localized: "第 \(run.stage) 關規則「\(m.name)」：\(m.desc)")
        }
        if run.has(.eye) {
            let eye = String(localized: "千里眼：送你 1 個透視")
            text = text.isEmpty ? eye : text + "\n" + eye
        }
        if !text.isEmpty { showToast(text, seconds: 2.8) }
    }

    // MARK: - Endless

    /// 「繼續無盡關卡」 on the win result: keeps coins, blessings and items, goes through the shop to stage 7.
    func startEndless() {
        guard sheet == .result, run.phase == .win, !run.endless else { return }
        run.endless = true
        run.phase = .shop
        run.shopOffer = Shop.shopOffer(run)
        recordDeepest()
        save()
        playSound("Click")
        sheet = .shop
    }

    // MARK: - Fail panel

    /// 「結束這局」
    func endRun() {
        guard sheet == .fail, run.phase == .play else { return }
        GameEngine.failStage(&run)
        save()
        sheet = .result
    }

    /// 「看廣告，多 2 手」: mocked ad, callback after 2.5s, once per run.
    func watchAd() {
        guard sheet == .fail, run.phase == .play, !run.adUsed, !adPlaying else { return }
        sheet = nil
        adPlaying = true
        flowTask = Task {
            await self.sleeper(self.timing.ad)
            guard !Task.isCancelled else { return }
            self.adPlaying = false
            GameEngine.reviveWithAd(&self.run)
            self.save()
            self.dealFaces()
            self.isLocked = false
            self.showToast(String(localized: "多了 2 手"))
        }
    }

    // MARK: - New run

    /// 「再來一局」: a new random deck at the difficulty just played.
    func startNewRun() {
        guard sheet == .result else { return }
        begin(seed: randomSeed(), lv: run.lv)
    }

    /// 「同一副牌再打」: same seed and difficulty, so every pair is dealt again identically.
    func retrySameDeck() {
        guard sheet == .result else { return }
        begin(seed: run.seed, lv: run.lv)
    }

    /// A level in the difficulty sheet (also 「挑戰難度「X」」 on the win result): new free run, remembered in `lastLevel`.
    func startLevel(_ lv: Int) {
        guard sheet == .difficulty || sheet == .result,
              (0...Rules.difficulties.count - 1).contains(lv), lv <= unlock else { return }
        store.update { $0.lastLevel = lv }
        syncFromStore()
        begin(seed: randomSeed(), lv: lv)
        showToast(String(localized: "自由練習 · 難度「\(Rules.difficulties[lv].name)」"), seconds: 2)
    }

    private func begin(seed: UInt32, lv: Int) {
        flowTask?.cancel()
        flowTask = nil
        shopLockTask?.cancel()
        shopBusy = false
        adPlaying = false
        sheet = nil
        difficultyReturn = nil
        run = Self.freshRun(seed: seed, lv: lv)
        save()
        dealFaces()
        isLocked = false
        playSound("start")
    }

    // MARK: - Difficulty sheet (02 §9)

    /// A free run that has started: leaving it counts as abandoning it.
    var runInProgress: Bool {
        run.phase == .play && (run.stage > 1 || run.picks < run.stagePicksAtStart)
    }

    /// From the top-bar chip (main screen) or 「換難度」 (result sheet).
    func openDifficulty() {
        if sheet == nil {
            guard canInteract else { return }
            difficultyReturn = nil
        } else if sheet == .result {
            difficultyReturn = .result
        } else {
            return
        }
        sheet = .difficulty
    }

    func closeDifficulty() {
        guard sheet == .difficulty else { return }
        sheet = difficultyReturn
        difficultyReturn = nil
    }

    // MARK: - Items

    func useItem(_ item: ItemID) {
        guard !isLocked, sheet == nil, !adPlaying, run.phase == .play, run.picks > 0 else { return }
        switch item {
        case .shield:
            if run.shield > 0 {
                showToast(String(localized: "保命符 ×\(run.shield)：選到會爆的牌時自動擋下，不扣手數，連中也不會斷"), seconds: 2.8)
            } else {
                showToast(String(localized: "沒有保命符了，過關後可以在商店買"))
            }
            return
        case .peek:
            guard run.inventory.peek > 0, !run.peekArmed else { return }
            run.inventory.peek -= 1
            run.peekArmed = true
            showToast(String(localized: "透視：這一手的結果已經顯示在牌上"))
        case .dbl:
            guard run.inventory.dbl > 0, !run.doubleArmed else { return }
            run.inventory.dbl -= 1
            run.doubleArmed = true
            showToast(String(localized: "雙倍：下一張牌的得分加倍"))
        case .roll:
            guard run.inventory.roll > 0 else { return }
            run.inventory.roll -= 1
            run.rerolls += 1
            run.peekArmed = false
            run.pair = GameEngine.genPair(run)
            showToast(String(localized: "重抽：換了一組新牌"))
        }
        playSound("Click")
        save()
        faces = makeFaces()
        if item == .roll { dealID += 1 }
    }

    // MARK: - Copy helpers for the views

    /// Shop wording of the coin breakdown (02 §4.1).
    func shopLabel(for part: RewardPart) -> String {
        switch part.kind {
        case .base: return String(localized: "過關基本")
        case .picksLeft: return String(localized: "剩下的手數（每手 $\(GameEngine.modOf(run) == .rich ? 2 : 1)）")
        case .stretch: return String(localized: "打到超標線")
        case .interest: return String(localized: "祝福「利息」")
        }
    }

    func label(for part: RewardPart) -> String {
        switch part.kind {
        case .base: return String(localized: "基本")
        case .picksLeft: return String(localized: "剩 \(run.picks) 手")
        case .stretch: return String(localized: "超標")
        case .interest: return String(localized: "利息")
        }
    }

    // MARK: - Toast

    func showToast(_ text: String, seconds: Double? = nil) {
        toastCounter += 1
        let t = Toast(id: toastCounter, text: text)
        toast = t
        toastTask?.cancel()
        toastTask = Task {
            await self.sleeper(seconds ?? self.timing.toast)
            if !Task.isCancelled, self.toast?.id == t.id { self.toast = nil }
        }
    }

    // MARK: - Side effects

    private func save() {
        let snapshot = run
        store.update { $0.runs.free = snapshot }
    }

    private func playSound(_ name: String) {
        sound?.play(name)
    }

    private func playTick(_ step: Int) {
        playSound("Click")
    }

    private func haptic(_ f: () -> Void) {
        guard feedbackEnabled else { return }
        f()
    }

    /// Lets tests wait for the current flow (pick, clear, ad) to finish.
    func waitUntilSettled() async {
        await flowTask?.value
        await shopLockTask?.value
    }
}
