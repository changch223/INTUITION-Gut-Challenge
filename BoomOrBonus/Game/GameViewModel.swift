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
        case rules         // the ? button: the rules panel with its buttons (02 §2.1, §8)
        case dashboard     // the ★ button: 我的紀錄 (02 §10)
    }

    /// The gold capsule under the score, `★ 新紀錄　最長連中 9` (02 §6).
    struct RecordPill: Equatable, Identifiable {
        let id: Int
        let record: RecordID
        let value: Int
        var text: String { String(localized: "★ 新紀錄　") + record.name + " " + Fmt.int(value) }
    }

    struct Toast: Equatable, Identifiable {
        let id: Int
        let text: String
        /// Drawn above the sheet scrim (the copy confirmation on the result sheet); other toasts sit on the game.
        var overSheet = false
    }

    // MARK: - State

    private(set) var run: RunState
    private(set) var faces: [CardFace] = []
    private(set) var pickedIndex: Int?
    private(set) var reveal: Reveal?
    private(set) var isLocked = false
    private(set) var sheet: Sheet?
    /// An ad flow is in progress (mock, rewarded or interstitial): no taps reach the game.
    private(set) var adPlaying = false
    /// True only for the Debug 2.5 s stand-in: the game screen draws its overlay. Real ads cover the screen themselves.
    private(set) var adIsMock = false
    /// The rewarded ad can be shown right now (fail sheet button enabled). Published by the ad manager.
    private(set) var rewardedReady = false
    /// A rewarded load failed (and none succeeded since): the button says it cannot load, not that it is loading.
    private(set) var rewardedLoadFailed = false
    private(set) var toast: Toast?
    /// The new-record pill on screen (2.4 s); more pills wait in a queue so they never overlap.
    private(set) var recordPill: RecordPill?
    #if DEBUG
    /// Every pill issued since launch, in order (tests only; a pill is logged when it is queued).
    @ObservationIgnored private(set) var pillLog: [RecordPill] = []
    #endif
    private(set) var dealID = 0
    private(set) var shakeCount = 0
    /// Mirrors of SaveData so views observe them (SaveStore itself is not observable).
    private(set) var unlock = 0
    private(set) var lastLevel = 0
    private(set) var deepest = 0
    private(set) var muted = false
    /// Where 「取消」 in the difficulty sheet goes back to (the result sheet, or nothing).
    private(set) var difficultyReturn: Sheet?
    /// 02 §7: the coach mark step being shown (0-based), nil when the onboarding is not running.
    private(set) var coachStep: Int?

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
    @ObservationIgnored private var pillQueue: [RecordPill] = []
    @ObservationIgnored private(set) var pillTask: Task<Void, Never>?
    @ObservationIgnored private var pillGeneration = 0

    @ObservationIgnored private let store: SaveStore
    @ObservationIgnored private let timing: Timing
    @ObservationIgnored private let sleeper: Sleeper
    @ObservationIgnored private let reduceMotion: @MainActor () -> Bool
    @ObservationIgnored private var sound: SoundPlayer?
    @ObservationIgnored private let ads: AdServices
    /// Bumped whenever the flows are cancelled: a late ad callback for an older run is ignored.
    @ObservationIgnored private var adToken = 0
    /// Ads on screen right now; the game is silent while it is above 0 (a stale callback still releases its share).
    @ObservationIgnored private var adSilenceDepth = 0
    @ObservationIgnored private let feedbackEnabled: Bool
    @ObservationIgnored private let randomSeed: () -> UInt32
    @ObservationIgnored private let hooks: DebugHooks
    @ObservationIgnored private let clock: DayKey.Provider

    // MARK: - Setup

    /// One shared instance for the app, so a re-created GameScreen never re-runs init side effects.
    /// A new install starts in the daily challenge (prototype `load('daily')`); after that the last mode is kept.
    static let live = GameViewModel(
        store: .shared, launchSeed: debugLaunchSeed(), hooks: DebugHooks.parse(),
        today: DayKey.debugToday().map { fake in { fake } } ?? { DayKey.today() }, defaultMode: .daily,
        showsOnboarding: !TestHost.isUnitTesting)

    /// - Parameter launchSeed: starts a new free run with this seed and ignores any save (QA hook).
    ///   It also resets unlock / lastLevel / deepest so every launch starts from the same state.
    /// - Parameter hooks: Debug-only launch arguments (`-stage`, `-blessings`, ...), only used with `launchSeed`.
    /// - Parameter today: the date provider (`YYYYMMDD`, local time); tests and `-today` replace it.
    /// - Parameter defaultMode: the mode when the save has none yet (the app passes `.daily`).
    /// - Parameter showsOnboarding: the app passes true: the coach marks open by themselves until they were finished
    ///   or skipped once (`onboardingDone`). With `-seed` only the `-onboarding` hook turns them on.
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
        randomSeed: @escaping () -> UInt32 = { UInt32.random(in: 0..<2147483647) },
        today: @escaping DayKey.Provider = { DayKey.today() },
        defaultMode: Mode = .free,
        showsOnboarding: Bool = false,
        ads: AdServices? = nil
    ) {
        self.store = store
        self.timing = timing
        self.sleeper = sleeper
        self.reduceMotion = reduceMotion ?? { UIAccessibility.isReduceMotionEnabled }
        self.feedbackEnabled = feedbackEnabled
        self.randomSeed = randomSeed
        self.hooks = hooks
        self.clock = today
        self.ads = ads ?? AdServices.current()
        if feedbackEnabled { self.sound = SoundPlayer(isMuted: { [store] in store.data.muted }) }
        self.rewardedReady = self.ads.rewarded?.isReady ?? self.ads.mockRewarded
        self.rewardedLoadFailed = self.ads.rewarded?.loadFailed ?? false

        var needsSave = false
        let initial: RunState
        if let launchSeed {
            store.update {
                $0.unlock = min(5, max(0, hooks.unlock ?? 0))
                $0.lastLevel = 0
                $0.deepest = 0
                // QA launches skip the onboarding (it would cover every UI test) unless `-onboarding` asks for it.
                $0.onboardingDone = !hooks.onboarding
                $0.runsSinceInterstitial = max(0, hooks.adCounter ?? 0)
                if let seed = hooks.stats { Self.seedStats(&$0, kind: seed, today: today()) }
            }
            let day = today()
            var r = Self.makeRun(mode: hooks.daily ? .daily : .free, seed: launchSeed, lv: hooks.lv ?? 0,
                                 data: store.data, day: day, randomSeed: randomSeed)
            hooks.apply(to: &r)
            initial = r
            needsSave = true
        } else {
            // 03 §2.1: yesterday's unfinished daily run is void (and is not an attempt).
            let day = today()
            Self.discardStaleDaily(store, today: day)
            let mode = store.data.mode ?? defaultMode
            if var restored = store.restorableRun(mode, today: day) {
                if restored.day == 0 { restored.day = day }     // saved before runs carried a day
                initial = restored
            } else {
                initial = Self.makeRun(mode: mode, seed: nil, lv: nil, data: store.data, day: day, randomSeed: randomSeed)
                needsSave = true
            }
        }
        self.run = initial
        self.faces = makeFaces()
        syncFromStore()
        if resumeRun() { needsSave = true }
        if needsSave { save() }
        self.ads.rewarded?.onReadyChange = { [weak self] _ in
            guard let self, let r = self.ads.rewarded else { return }
            self.rewardedReady = r.isReady
            self.rewardedLoadFailed = r.loadFailed
        }
        let wantsOnboarding = launchSeed != nil ? hooks.onboarding : showsOnboarding
        if wantsOnboarding, !store.data.onboardingDone, sheet == nil, canInteract { coachStep = 0 }
    }

    /// Opens whatever the current run was waiting for (shop, result, a stage that ended). True when `run` changed.
    private func resumeRun() -> Bool {
        var changed = false
        switch run.phase {
        case .shop:
            // 03 §2.1: reopen the shop; the same shelf comes back from the save.
            if run.shopOffer.isEmpty { run.shopOffer = Shop.shopOffer(run); changed = true }
            isLocked = true
            sheet = .shop
        case .win:
            // Only reachable through the debug hooks (a saved win is not restored).
            settleClear()
            finishRun()
            changed = true
            isLocked = true
            sheet = .result
        case .over:
            finishRun()
            changed = true
            isLocked = true
            sheet = .result
        case .play:
            if run.picks <= 0 {
                // Killed between the last pick and the stage-end resolution.
                isLocked = true
                flowTask = Task { await self.resolveStageEnd() }
            }
        }
        return changed
    }

    /// 03 §2.2: a new free run starts at min(lastLevel, unlock).
    static func startLevel(_ data: SaveData) -> Int { min(data.lastLevel, data.unlock) }

    private func syncFromStore() {
        unlock = store.data.unlock
        lastLevel = store.data.lastLevel
        deepest = store.data.deepest
        muted = store.data.muted
    }

    /// `-stats sample|low` (Debug builds, `-seed` launches only, so only ever the `save-qa.json` file):
    /// fills the stats and the daily history so the records page can be looked at populated.
    private static func seedStats(_ data: inout SaveData, kind: DebugHooks.StatsSeed, today: Int) {
        switch kind {
        case .sample:
            let sample = SampleData.make(today: today)
            data.stats = sample.stats
            data.daily = sample.daily
            data.unlock = max(data.unlock, sample.unlock)
        case .low:
            // One finished run with every record at 1: the next safe pick or two breaks some, so a pill shows.
            var s = Stats()
            s.runs = 1
            s.byLevel[0] = Stats.Tally(runs: 1, clears: 0, best: 1)
            for id in RecordID.allCases { s.raise(id, to: 1, day: DayKey.adding(-1, to: today)) }
            data.stats = s
        }
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

    /// 03 §2.2. Daily: `seed = day`, lv 0, x1.3, `attempt = tries + 1`. Free: the given or a random seed at the
    /// given or the remembered level. Every run carries the day it started on.
    private static func makeRun(
        mode: Mode, seed: UInt32?, lv: Int?, data: SaveData, day: Int, randomSeed: () -> UInt32
    ) -> RunState {
        var r: RunState
        switch mode {
        case .daily:
            r = GameEngine.newRun(seed: UInt32(truncatingIfNeeded: day), lv: 0, mode: .daily, targetMul: Rules.DAILY_TM)
            r.attempt = (data.daily[day]?.tries ?? 0) + 1
        case .free:
            r = GameEngine.newRun(seed: seed ?? randomSeed(), lv: lv ?? startLevel(data), mode: .free)
        }
        r.day = day
        return r
    }

    /// 03 §2.1: an unfinished daily run from an earlier day is dropped from the save. Not an attempt.
    private static func discardStaleDaily(_ store: SaveStore, today: Int) {
        guard let d = store.data.runs.daily, d.day != today, d.phase == .play || d.phase == .shop else { return }
        store.update { $0.runs.daily = nil }
    }

    var mode: Mode { run.mode }
    var today: Int { clock() }

    /// 我的紀錄 reads these (SaveStore is not observable; the sheet reads them when it opens).
    var stats: Stats { store.data.stats }
    var dailyLog: [Int: DailyRecord] { store.data.daily }
    /// True once there is anything to show: a finished run or a daily attempt (prototype `empty`).
    var hasRecords: Bool { store.data.stats.runs > 0 || !store.data.daily.isEmpty }

    /// The records broken in this run with their current values (result sheet, 「這局剛破」).
    var brokenRecords: [(id: RecordID, value: Int)] {
        run.brokenRecords.compactMap { raw in
            guard let id = RecordID(rawValue: raw), let v = store.data.stats.value(id) else { return nil }
            return (id, v)
        }
    }

    /// The attempt number the next daily run will get (the result sheet's 「再挑戰一次（第 N 次）」).
    var nextDailyAttempt: Int { (store.data.daily[today]?.tries ?? 0) + 1 }

    // MARK: - Derived

    var target: Int { GameEngine.target(run) }
    var stretch: Int { GameEngine.stretch(run) }
    var adDuration: Double { timing.ad }
    /// 02 §12: banners only on the shop and the result sheet (and only when ads are on).
    var bannerVisible: Bool { ads.bannersEnabled && AdPlacement.showsBanner(on: sheet) }
    var canClear: Bool { GameEngine.canClear(run) }
    var reward: Int { GameEngine.reward(run) }
    var isFirstPick: Bool { run.picks == run.stagePicksAtStart }
    var smult: Double { GameEngine.smult(run) }
    var boss: BossID? { GameEngine.bossOf(stage: run.stage) }
    var mod: ModID? { GameEngine.modOf(run) }

    /// Taps on cards, items and the bank button only work while this is true.
    var canInteract: Bool {
        !isLocked && sheet == nil && !adPlaying && coachStep == nil && run.phase == .play && run.picks > 0
    }

    private var reduced: Bool { reduceMotion() }
    private var effectiveTiming: Timing { reduced ? timing.reduced : timing }

    // MARK: - Pick flow

    func pick(_ i: Int) {
        if refreshDay() { return }
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
        let stats = recordPick(ev)          // written together with the run below, in one save

        switch ev {
        case .safe(let delta):
            reveal = .safe(delta: delta)
            play(.safe(run.streak))
            haptic { HapticManager.shared.playSuccess() }
            if (v0 < tgt || first) && run.value >= tgt && run.picks > 0 {
                play(.goal)
                showToast(String(localized: "達標！可以過關，也可以拚超標 \(Fmt.int(GameEngine.stretch(run)))"), seconds: 2.4)
            }
        case .boom(let lost, let s0, let s1):
            reveal = .boom(lost: lost)
            play(.boom)
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
            play(.shield)
            haptic { HapticManager.shared.playClick() }
            showToast(String(localized: "保命符擋下爆炸：這手不算、不扣手數，連中保留（剩 \(run.shield) 張）"), seconds: 2.8)
        case .defuse:
            reveal = .defuse
            play(.shield)
            haptic { HapticManager.shared.playClick() }
            showToast(String(localized: "拆彈：這關第一次爆炸無效，不扣手數"), seconds: 2.8)
        }

        // Deal the next pair now (engine genPair after pickCard, as core.js / prototype.html),
        // so the save is consistent. The screen keeps showing the old faces until the deal delay ends.
        if run.picks > 0 { run.pair = GameEngine.genPair(run) }
        save(stats: stats)

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
            play(.fail)
            if !run.adUsed {
                sheet = .fail
            } else {
                GameEngine.failStage(&run)
                finishRun()
                presentResult()
            }
        }
    }

    /// The bank button.
    func bank() {
        if refreshDay() { return }
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
        let stats = recordStageClear()
        play(.clear)
        haptic { HapticManager.shared.playSuccess() }
        if run.phase == .win { finishRun(stats: stats) } else { save(stats: stats) }
        let win = run.phase == .win
        await sleeper(win ? timing.winToSheet : timing.clearToSheet)
        guard !Task.isCancelled else { return }
        if win { presentResult() } else { sheet = .shop }
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
        afterShopAction(coin: false)
    }

    private func afterShopAction(coin: Bool = true) {
        play(coin ? .coin : .item)
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
        if refreshDay() { return }
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
        if refreshDay() { return }
        guard sheet == .fail, run.phase == .play, !adPlaying else { return }
        GameEngine.failStage(&run)
        finishRun()
        presentResult()
    }

    /// The fail sheet's button can be tapped: a rewarded ad is loaded (or, Debug with -noAds / -seed, the mock).
    var canWatchAd: Bool { rewardedReady && !run.adUsed }
    /// The fail sheet's button label: ready, still loading, or the load failed.
    var adButtonState: AdButtonState { rewardedReady ? .ready : (rewardedLoadFailed ? .failed : .loading) }
    enum AdButtonState { case ready, loading, failed }

    /// 「看廣告，多 2 手」, once per run. The extra picks are granted only after the ad reports the reward and
    /// closes; closing it early, or a failed presentation, leaves the fail sheet as it was.
    func watchAd() {
        if refreshDay() { return }
        guard sheet == .fail, run.phase == .play, !run.adUsed, !adPlaying, rewardedReady else { return }
        if let rewarded = ads.rewarded {
            adPlaying = true
            adIsMock = false
            setAdSilence(true)
            let token = adToken
            let silence = SilenceRelease()
            rewarded.show { [weak self] outcome in
                guard let self else { return }
                // Once per presentation (a late reward after a timeout calls back twice), and even if the run
                // was replaced meanwhile (e.g. midnight).
                if silence.release() { self.setAdSilence(false) }
                guard token == self.adToken else { return }
                self.adPlaying = false
                // `rewardedReady` follows the manager: it is already false for a spent or failed ad.
                // After a presentation timeout the manager may report a late `.rewarded` for a player who watched it.
                if outcome == .rewarded { self.grantAdPicks() }
            }
            return
        }
        #if DEBUG
        guard ads.mockRewarded else { return }
        sheet = nil
        adPlaying = true
        adIsMock = true
        flowTask = Task {
            await self.sleeper(self.timing.ad)
            guard !Task.isCancelled else { return }
            self.adPlaying = false
            self.adIsMock = false
            self.grantAdPicks()
        }
        #endif
    }

    private func grantAdPicks() {
        guard run.phase == .play, !run.adUsed else { return }
        sheet = nil
        GameEngine.reviveWithAd(&run)
        save()
        dealFaces()
        isLocked = false
        showToast(String(localized: "多了 2 手"))
    }

    /// Mutes the game while an ad is on screen, and re-arms the audio session once it is gone.
    /// One presentation's share of the ad-silence counter: releasing it twice does nothing.
    private final class SilenceRelease {
        private var released = false
        func release() -> Bool { defer { released = true }; return !released }
    }

    private func setAdSilence(_ on: Bool) {
        adSilenceDepth = max(0, adSilenceDepth + (on ? 1 : -1))
        sound?.suspended = adSilenceDepth > 0
    }

    // MARK: - Result sheet and the interstitial (02 §12)

    /// One interstitial per this many finished runs.
    static let interstitialEvery = 3

    /// Opens the result sheet for a run that just finished. Before it, maybe an interstitial: every third finished
    /// run, never on the first daily attempt of the day, and only when the ad is loaded (otherwise it is skipped
    /// silently and the counter stays due). The sheet appears when the ad closes, or at once without one.
    private func presentResult() {
        // A won run that goes on into endless shows its result a second time: it was counted (and maybe shown) once.
        if run.endless { sheet = .result; return }
        store.update { $0.runsSinceInterstitial += 1 }
        let firstDailyAttempt = run.mode == .daily && run.attempt <= 1
        guard let ad = ads.interstitial,
              store.data.runsSinceInterstitial >= Self.interstitialEvery,
              !firstDailyAttempt, ad.isReady else {
            sheet = .result
            return
        }
        adPlaying = true
        adIsMock = false
        setAdSilence(true)
        let token = adToken
        let silence = SilenceRelease()
        ad.show { [weak self] shown in
            guard let self else { return }
            if silence.release() { self.setAdSilence(false) }
            // The counter restarts only after the ad really appeared; otherwise it stays due.
            if shown { self.store.update { $0.runsSinceInterstitial = 0 } }
            guard token == self.adToken else { return }
            self.adPlaying = false
            self.sheet = .result
        }
    }

    // MARK: - New run

    /// 「再來一局」: a new random deck at the difficulty just played (free play).
    func startNewRun() {
        guard sheet == .result else { return }
        if run.mode == .daily { retrySameDeck(); return }
        begin(.free, seed: randomSeed(), lv: run.lv)
    }

    /// 「同一副牌再打」 / 「再挑戰一次」: free play deals the same seed and difficulty again;
    /// the daily challenge starts the next attempt on today's deck (`attempt = tries + 1`).
    func retrySameDeck() {
        guard sheet == .result else { return }
        if run.mode == .daily { begin(.daily) } else { begin(.free, seed: run.seed, lv: run.lv) }
    }

    /// A level in the difficulty sheet (also 「挑戰難度「X」」 on the win result): new free run, remembered in `lastLevel`.
    /// The new run is always free play: the difficulty does not apply to the daily challenge.
    func startLevel(_ lv: Int) {
        // From the daily challenge (chip -> sheet) this starts a free run and leaves the daily run saved as it is,
        // and a free run waiting in the save is replaced without counting (prototype `startFree`).
        guard (sheet == .difficulty) || (sheet == .result && run.mode == .free),
              (0...Rules.difficulties.count - 1).contains(lv), lv <= unlock else { return }
        // 02 §9: leaving a free run that has started for another difficulty records it as abandoned, the same
        // path as 「放棄重來」 (counts the run, the abandon, byLevel and byBlessing).
        if run.mode == .free, runInProgress {
            GameEngine.failStage(&run)
            run.abandoned = true
            finishRun()
        }
        store.update { $0.lastLevel = lv }
        syncFromStore()
        save()
        begin(.free, seed: randomSeed(), lv: lv)
        showToast(String(localized: "自由練習 · 難度「\(Rules.difficulties[lv].name)」"), seconds: 2)
    }

    /// Replaces the current run with a new one of `mode` (the old run is not saved: callers decide what it was).
    private func begin(_ mode: Mode, seed: UInt32? = nil, lv: Int? = nil) {
        cancelFlows()
        clearPills()
        let day = today
        Self.discardStaleDaily(store, today: day)
        run = Self.makeRun(mode: mode, seed: seed, lv: lv, data: store.data, day: day, randomSeed: randomSeed)
        save()
        dealFaces()
        isLocked = false
        playSound("start")
    }

    private func cancelFlows() {
        flowTask?.cancel()
        flowTask = nil
        shopLockTask?.cancel()
        shopBusy = false
        adPlaying = false
        adIsMock = false
        adToken += 1
        sheet = nil
        difficultyReturn = nil
    }

    // MARK: - Modes (02 §11)

    /// Both modes keep their own run in the save (`runs.daily` / `runs.free`). Switching is not an attempt.
    /// Blocked only while a pick / clear animation runs (locked with no sheet up) or the mock ad plays.
    /// With a sheet open the run is idle, so switching is fine: the run is saved and comes back with its sheet.
    var canSwitchMode: Bool { !adPlaying && coachStep == nil && !(isLocked && sheet == nil) }

    func switchMode(_ new: Mode) {
        guard new != run.mode, canSwitchMode else { return }
        save()                                           // the run being left stays exactly as it is
        cancelFlows()
        clearPills()
        let day = today
        Self.discardStaleDaily(store, today: day)
        isLocked = false
        pickedIndex = nil
        reveal = nil
        if var restored = store.restorableRun(new, today: day) {
            if restored.day == 0 { restored.day = day }
            run = restored
        } else {
            run = Self.makeRun(mode: new, seed: nil, lv: nil, data: store.data, day: day, randomSeed: randomSeed)
        }
        faces = makeFaces()
        dealID += 1
        _ = resumeRun()
        save()
        playSound("Click")
    }

    /// Launch (init), foreground and run start all go through here: an unfinished daily run from an earlier day
    /// is discarded without counting as an attempt, and replaced by today's attempt when it is on screen.
    /// Also called when the app sees a significant time change (midnight, clock or time zone) and at the top of
    /// every action that could end or advance a run, so a run left open past midnight never counts against
    /// yesterday. Returns true when the run was replaced (the caller's action no longer applies).
    @discardableResult
    func refreshDay() -> Bool {
        let t = today
        Self.discardStaleDaily(store, today: t)
        guard run.mode == .daily, run.day != t, run.phase == .play || run.phase == .shop else { return false }
        begin(.daily)
        showToast(String(localized: "新的一天，今日挑戰第 \(run.attempt) 次"), seconds: 2.4)
        return true
    }

    /// 「複製戰績」: the share text (ShareText) goes to the system pasteboard.
    func copyResult() {
        guard sheet == .result else { return }
        UIPasteboard.general.string = ShareText.make(run)
        playSound("Click")
        showToast(String(localized: "已複製戰績"), overSheet: true)
    }

    // MARK: - ? rules panel (02 §8)

    func openRules() {
        if refreshDay() { return }
        guard sheet == nil, canInteract else { return }
        sheet = .rules
    }

    func closeRules() {
        guard sheet == .rules else { return }
        sheet = nil
    }

    func toggleMute() {
        guard sheet == .rules else { return }
        store.update { $0.muted.toggle() }
        syncFromStore()
        if !muted { playSound("Click") }
    }

    /// 「放棄（算一次）」 / 「放棄重來」, on the rules panel. Daily: ends the run as a failed attempt (even with no pick made),
    /// counts one try and starts the next attempt. Free: ends the run (only if it had started) and deals a new one.
    func abandon() {
        if refreshDay() { return }
        guard run.phase == .play, !isLocked, !adPlaying, sheet == nil || sheet == .rules else { return }
        let mode = run.mode, lv = run.lv
        if mode == .daily || runInProgress {
            GameEngine.failStage(&run)
            run.abandoned = true
            finishRun()
        }
        if mode == .daily {
            begin(.daily)
            showToast(String(localized: "已放棄，開始第 \(run.attempt) 次挑戰"), seconds: 2)
        } else {
            begin(.free, seed: randomSeed(), lv: lv)
            showToast(String(localized: "已放棄這局，換一副新牌"), seconds: 2)
        }
    }

    /// A run ended (cleared all six stages, out of picks for good, or abandoned). Daily runs update the day's
    /// DailyRecord here, and every run updates the stats and the end-of-run records (03 §4), all in one write
    /// together with the run itself. Calling it again for the same run (endless ending after a clear) does not
    /// count the run again: it only refreshes total, marks, the best totals and the records.
    private func finishRun(stats pending: Stats? = nil) {
        var stats = pending ?? store.data.stats
        var record: DailyRecord?
        if run.mode == .daily {
            var r = store.data.daily[run.day] ?? DailyRecord()
            r.finish(&run)
            record = r
        }
        // Finish-time records are listed on the result sheet; they do not pop a pill on the game behind it.
        noteBroken(countFinish(&stats), pill: false)
        let snapshot = run, day = run.day
        store.update {
            $0.stats = stats
            if let record {
                $0.daily[day] = record
                $0.runs.daily = snapshot
                $0.mode = .daily
            } else {
                $0.runs.free = snapshot
                $0.mode = .free
            }
        }
    }

    // MARK: - Stats and records (03 §4)

    /// The ids that already had a record before this run: only those can pop a pill (so run 1 never does).
    /// Taken at the first check of a run, before that run changes any record.
    private func ensureRecordBase() {
        if run.recordBase == nil {
            run.recordBase = store.data.stats.records.keys.map(\.rawValue).sorted()
        }
    }

    /// Per reveal: the counters, and on a safe pick the 單手最高得分 and 最長連中 records.
    /// Returns the new stats; the caller writes them with the run (one write per pick).
    private func recordPick(_ ev: PickEvent) -> Stats {
        ensureRecordBase()
        var stats = store.data.stats
        stats.countPick(ev)
        var broken: [(RecordID, Int)] = []
        if case .safe(let delta) = ev {
            if stats.raise(.pick, to: delta, day: today) { broken.append((.pick, delta)) }
            if stats.raise(.streak, to: run.streak, day: today) { broken.append((.streak, run.streak)) }
        }
        noteBroken(broken, pill: true)
        return stats
    }

    /// Per stage clear: 單關最高分 with the score the stage ended on (still in `run.value` here).
    /// The winning clear (stage 6) goes to the result sheet instead of a pill. The caller writes the stats.
    private func recordStageClear() -> Stats {
        ensureRecordBase()
        var stats = store.data.stats
        if stats.raise(.stage, to: run.value, day: today) {
            noteBroken([(.stage, run.value)], pill: run.phase != .win)
        }
        return stats
    }

    /// The finish part: run counters once (`statsCounted`), best totals, and 單局最高總分 / 最多過關數 / 單局賺到最多金幣.
    /// Mutates `stats` (the caller writes it) and returns the records that broke.
    private func countFinish(_ stats: inout Stats) -> [(RecordID, Int)] {
        ensureRecordBase()
        if !run.statsCounted {
            let six = run.marks.prefix(Rules.STAGES)
            stats.countRun(mode: run.mode, lv: run.lv,
                           won: DailyRecord.isWin(run.marks),
                           allSuper: six.count == Rules.STAGES && six.allSatisfy { $0 == 2 },
                           abandoned: run.abandoned,
                           blessings: BlessingID.allCases.filter { run.has($0) })
            run.statsCounted = true
        }
        stats.raiseBest(mode: run.mode, lv: run.lv, total: run.total)
        let cleared = run.marks.filter { $0 > 0 }.count
        var broken: [(RecordID, Int)] = []
        if stats.raise(.total, to: run.total, day: today) { broken.append((.total, run.total)) }
        if stats.raise(.deep, to: cleared, day: today) { broken.append((.deep, cleared)) }
        if stats.raise(.coins, to: run.coinsEarned, day: today) { broken.append((.coins, run.coinsEarned)) }
        return broken
    }

    /// A strict improvement: it is a new record for the run (listed, and with `pill` also announced) only if the
    /// record existed before this run and this run has not announced it yet.
    private func noteBroken(_ broken: [(RecordID, Int)], pill: Bool) {
        for (id, value) in broken {
            guard run.recordBase?.contains(id.rawValue) == true, !run.brokenRecords.contains(id.rawValue) else { continue }
            run.brokenRecords.append(id.rawValue)
            if pill { enqueuePill(id, value) }
        }
    }

    // MARK: - New-record pill (02 §6)

    static let pillSeconds = 2.4

    private func enqueuePill(_ id: RecordID, _ value: Int) {
        toastCounter += 1
        let pill = RecordPill(id: toastCounter, record: id, value: value)
        #if DEBUG
        pillLog.append(pill)
        #endif
        pillQueue.append(pill)
        guard pillTask == nil else { return }
        let generation = pillGeneration
        pillTask = Task { await self.drainPills(generation) }
    }

    /// One pill at a time, 2.4 s each, in the order they were earned.
    private func drainPills(_ generation: Int) async {
        while generation == pillGeneration, !pillQueue.isEmpty {
            recordPill = pillQueue.removeFirst()
            play(.coin)
            await sleeper(Self.pillSeconds)
        }
        guard generation == pillGeneration else { return }
        recordPill = nil
        pillTask = nil
    }

    /// A new run or another mode starts: pills of the run that was left must not show on the next one.
    private func clearPills() {
        pillGeneration += 1
        pillTask?.cancel()
        pillTask = nil
        pillQueue.removeAll()
        recordPill = nil
    }

    // MARK: - 我的紀錄 (02 §10)

    /// The ★ button, or 「我的紀錄」 on the rules panel.
    func openDashboard() {
        if refreshDay() { return }
        if sheet == .rules { sheet = .dashboard; return }
        guard sheet == nil, canInteract else { return }
        sheet = .dashboard
    }

    func closeDashboard() {
        guard sheet == .dashboard else { return }
        sheet = nil
    }

    /// Lets tests wait for the pill queue to run empty.
    func waitForPills() async {
        await pillTask?.value
    }

    // MARK: - Onboarding (02 §7)

    /// 「再看導覽」 on the rules panel: closes the panel and starts at step 1.
    func replayOnboarding() {
        guard sheet == .rules, !isLocked, !adPlaying else { return }
        sheet = nil
        coachStep = 0
    }

    /// 「下一步」; on the last step 「開始玩」 finishes.
    func nextCoach() {
        guard let step = coachStep else { return }
        playSound("Click")
        if step + 1 >= CoachStep.all.count { finishOnboarding() } else { coachStep = step + 1 }
    }

    /// 「跳過」: same as finishing, it is not shown again by itself.
    func skipCoach() {
        guard coachStep != nil else { return }
        playSound("Click")
        finishOnboarding()
    }

    private func finishOnboarding() {
        coachStep = nil
        store.update { $0.onboardingDone = true }
    }

    // MARK: - Difficulty sheet (02 §9)

    /// A free run that has started: leaving it counts as abandoning it.
    var runInProgress: Bool {
        run.phase == .play && (run.stage > 1 || run.picks < run.stagePicksAtStart)
    }

    /// Picking a level replaces the saved free run. In daily mode that is the free run waiting in the save;
    /// either way it is only a warning in the sheet, not an abandon (prototype `startFree`).
    var difficultyReplacesRun: Bool {
        if run.mode == .free { return runInProgress }
        guard let free = store.restorableRun(.free, today: 0) else { return false }
        return free.stage > 1 || free.picks < free.stagePicksAtStart
    }

    /// From the top-bar chip (main screen) or 「換難度」 (result sheet).
    func openDifficulty() {
        if sheet == .rules { sheet = nil }      // 「選擇難度」 on the rules panel
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
        guard canInteract else { return }
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
        play(.item)
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

    func showToast(_ text: String, seconds: Double? = nil, overSheet: Bool = false) {
        toastCounter += 1
        let t = Toast(id: toastCounter, text: text, overSheet: overSheet)
        toast = t
        toastTask?.cancel()
        toastTask = Task {
            await self.sleeper(seconds ?? self.timing.toast)
            if !Task.isCancelled, self.toast?.id == t.id { self.toast = nil }
        }
    }

    // MARK: - Side effects

    private func save(stats: Stats? = nil) {
        let snapshot = run
        store.update {
            if let stats { $0.stats = stats }
            if snapshot.mode == .daily { $0.runs.daily = snapshot } else { $0.runs.free = snapshot }
            $0.mode = snapshot.mode
        }
    }

    private func playSound(_ name: String) {
        sound?.play(name)
    }

    private func play(_ sfx: Sfx) {
        sound?.play(sfx)
    }

    private func playTick(_ step: Int) {
        play(.tick(step))
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
