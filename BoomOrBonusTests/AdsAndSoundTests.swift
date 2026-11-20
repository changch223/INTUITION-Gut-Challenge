//
//  AdsAndSoundTests.swift
//  BoomOrBonusTests
//
//  Phase 7a: rewarded flow, interstitial frequency, banner placement, ad unit IDs and the synthesized sounds.
//  The view model gets protocol fakes; no ad SDK object is touched.
//

import AVFoundation
import XCTest
@testable import BoomOrBonus

@MainActor
final class FakeRewarded: RewardedAdProviding {
    var isReady: Bool { didSet { if isReady != oldValue { onReadyChange?(isReady) } } }
    var loadFailed = false { didSet { if loadFailed != oldValue { onReadyChange?(isReady) } } }
    var onReadyChange: ((Bool) -> Void)?
    private(set) var shown = 0
    private var pending: ((RewardedOutcome) -> Void)?

    init(ready: Bool) { isReady = ready }

    func show(completion: @escaping (RewardedOutcome) -> Void) {
        shown += 1
        pending = completion
    }

    /// The ad closes with this outcome; like the real manager the spent ad is no longer ready.
    func finish(_ outcome: RewardedOutcome) {
        let p = pending
        last = p
        pending = nil
        isReady = false
        p?(outcome)
    }

    /// The real manager keeps the completion after a timeout and calls it again if the ad shows up late.
    private var last: ((RewardedOutcome) -> Void)?
    func finishLate(_ outcome: RewardedOutcome) { last?(outcome) }
}

@MainActor
final class FakeInterstitial: InterstitialAdProviding {
    var isReady: Bool
    private(set) var shown = 0
    private var pending: ((Bool) -> Void)?

    init(ready: Bool = true) { isReady = ready }

    func show(completion: @escaping (Bool) -> Void) {
        shown += 1
        pending = completion
    }

    /// The ad was closed (`shown` true), or it could not be presented after all (false).
    func close(shown: Bool = true) {
        let p = pending
        pending = nil
        p?(shown)
    }
}

@MainActor
final class FakeConsentBackend: ConsentBackend {
    var canRequestAds = false
    var privacyOptionsRequired = false
    var updateError: Error?
    /// What a successful update (and the form) leaves behind.
    var grantsAfterUpdate = true
    private(set) var updates = 0
    private(set) var forms = 0

    func requestUpdate(completion: @escaping (Error?) -> Void) {
        updates += 1
        if updateError == nil, grantsAfterUpdate { canRequestAds = true }
        completion(updateError)
    }

    func presentFormIfRequired(completion: @escaping (Error?) -> Void) {
        forms += 1
        completion(nil)
    }

    func presentPrivacyOptions(completion: @escaping (Error?) -> Void) { completion(nil) }
}

@MainActor
final class AdsAndSoundTests: XCTestCase {

    // MARK: - Consent (UMP) with a fake backend

    private struct Offline: Error {}

    private func consent(_ backend: FakeConsentBackend, clock: @escaping () -> Date, started: @escaping () -> Void = {}) -> ConsentManager {
        ConsentManager(backend: backend, enabled: true, retryInterval: 30, now: clock, startAds: started)
    }

    func testConsentFailureIsTheFailedStateAndRetriesOnActivationThrottled() {
        let backend = FakeConsentBackend()
        backend.updateError = Offline()
        var t = Date(timeIntervalSince1970: 1_000)
        var adsStarted = 0
        let manager = consent(backend, clock: { t }, started: { adsStarted += 1 })
        var notified = 0
        manager.observe { notified += 1 }

        manager.start()
        XCTAssertEqual(backend.updates, 1)
        XCTAssertTrue(manager.failed, "offline on first launch: the ad button must not stay on 'loading'")
        XCTAssertFalse(manager.canRequestAds)
        XCTAssertEqual(adsStarted, 0)
        XCTAssertGreaterThan(notified, 0, "the ad managers are told")

        t += 5
        manager.appBecameActive()                      // too soon
        XCTAssertEqual(backend.updates, 1)

        t += 30
        manager.appBecameActive()                      // still offline: tried again, still failed
        XCTAssertEqual(backend.updates, 2)
        XCTAssertTrue(manager.failed)

        backend.updateError = nil
        t += 31
        manager.appBecameActive()                      // back online
        XCTAssertEqual(backend.updates, 3)
        XCTAssertTrue(manager.canRequestAds)
        XCTAssertFalse(manager.failed)
        XCTAssertEqual(adsStarted, 1)

        t += 100
        manager.appBecameActive()                      // nothing left to retry
        XCTAssertEqual(backend.updates, 3)
    }

    func testConsentFromAPreviousSessionStartsAdsAtOnce() {
        let backend = FakeConsentBackend()
        backend.canRequestAds = true
        backend.updateError = Offline()                // the refresh fails, the old consent still counts
        var adsStarted = 0
        let manager = consent(backend, clock: { Date() }, started: { adsStarted += 1 })
        manager.start()
        XCTAssertTrue(manager.canRequestAds)
        XCTAssertFalse(manager.failed)
        XCTAssertEqual(adsStarted, 1)
    }

    func testConsentDeniedCountsAsFailedAndPrivacyOptionsAreMirrored() {
        let backend = FakeConsentBackend()
        backend.grantsAfterUpdate = false
        backend.privacyOptionsRequired = true
        let manager = consent(backend, clock: { Date() })
        manager.start()
        XCTAssertFalse(manager.canRequestAds)
        XCTAssertTrue(manager.failed)
        XCTAssertTrue(manager.privacyOptionsRequired)
    }

    func testConsentManagerDoesNothingWhenDisabled() {
        let backend = FakeConsentBackend()
        let manager = ConsentManager(backend: backend, enabled: false, startAds: { XCTFail("no ads when suppressed") })
        manager.start()
        manager.appBecameActive()
        XCTAssertEqual(backend.updates, 0)
        XCTAssertFalse(manager.failed)
    }


    private let instant: GameViewModel.Sleeper = { _ in await Task.yield() }
    private let day = 20261116

    private func makeVM(store: SaveStore, ads: AdServices, today: Int? = nil) -> GameViewModel {
        GameViewModel(store: store, launchSeed: nil, sleeper: instant, reduceMotion: { false },
                      feedbackEnabled: false, randomSeed: { 12345 },
                      today: { today ?? self.day }, ads: ads)
    }

    private func lastPickRun(daily: Bool = false, attempt: Int = 1) -> RunState {
        var r = daily
            ? GameEngine.newRun(seed: UInt32(day), lv: 0, mode: .daily, targetMul: Rules.DAILY_TM)
            : GameEngine.newRun(seed: 20261116)
        if daily { r.day = day; r.attempt = attempt }
        r.picks = 1
        r.shield = 0
        r.pair = [boomCard(), boomCard()]
        return r
    }

    private func store(run: RunState, counter: Int = 0) -> SaveStore {
        let s = SaveStore(url: nil)
        s.update {
            if run.mode == .daily { $0.runs.daily = run; $0.mode = .daily } else { $0.runs.free = run; $0.mode = .free }
            $0.runsSinceInterstitial = counter
        }
        return s
    }

    /// Plays the last pick (it booms), lands on the fail sheet.
    private func toFailSheet(_ vm: GameViewModel) async {
        vm.pick(0)
        await vm.waitUntilSettled()
        XCTAssertEqual(vm.sheet, .fail)
    }

    // MARK: - Rewarded

    func testRewardedGrantsPicksOnlyAfterTheRewardAndClose() async {
        let ad = FakeRewarded(ready: true)
        let vm = makeVM(store: store(run: lastPickRun()), ads: AdServices(rewarded: ad))
        await toFailSheet(vm)
        XCTAssertTrue(vm.canWatchAd)

        vm.watchAd()
        XCTAssertEqual(ad.shown, 1)
        XCTAssertTrue(vm.adPlaying)
        XCTAssertFalse(vm.adIsMock, "a real ad is not drawn over by the mock overlay")
        XCTAssertFalse(vm.canInteract)
        XCTAssertEqual(vm.run.picks, 0, "no reward before the ad reports it")

        ad.finish(.rewarded)
        XCTAssertEqual(vm.run.picks, 2)
        XCTAssertTrue(vm.run.adUsed)
        XCTAssertNil(vm.sheet)
        XCTAssertFalse(vm.adPlaying)
        XCTAssertTrue(vm.canInteract)
        XCTAssertFalse(vm.canWatchAd, "once per run")
    }

    func testRewardedDismissedWithoutRewardReturnsToTheFailSheet() async {
        let ad = FakeRewarded(ready: true)
        let vm = makeVM(store: store(run: lastPickRun()), ads: AdServices(rewarded: ad))
        await toFailSheet(vm)
        vm.watchAd()
        ad.finish(.dismissed)

        XCTAssertEqual(vm.sheet, .fail)
        XCTAssertEqual(vm.run.picks, 0)
        XCTAssertFalse(vm.run.adUsed)
        XCTAssertFalse(vm.adPlaying)
        XCTAssertFalse(vm.canWatchAd, "the spent ad is gone until the next one loads")
        vm.endRun()                                   // the flow is not locked
        XCTAssertEqual(vm.sheet, .result)
    }

    func testRewardedPresentationFailureNeverLocksTheGame() async {
        let ad = FakeRewarded(ready: true)
        let vm = makeVM(store: store(run: lastPickRun()), ads: AdServices(rewarded: ad))
        await toFailSheet(vm)
        vm.watchAd()
        ad.finish(.failed)
        XCTAssertEqual(vm.sheet, .fail)
        XCTAssertFalse(vm.adPlaying)
        XCTAssertEqual(vm.run.picks, 0)
        vm.endRun()
        XCTAssertEqual(vm.sheet, .result)
    }

    func testRewardedNotLoadedDisablesTheButtonThenEnablesWhenReady() async {
        let ad = FakeRewarded(ready: false)
        let vm = makeVM(store: store(run: lastPickRun()), ads: AdServices(rewarded: ad))
        await toFailSheet(vm)
        XCTAssertFalse(vm.canWatchAd)

        vm.watchAd()                                  // ignored
        XCTAssertEqual(ad.shown, 0)
        XCTAssertFalse(vm.adPlaying)
        XCTAssertEqual(vm.sheet, .fail)

        ad.isReady = true                             // the background retry succeeded
        XCTAssertTrue(vm.canWatchAd)
        vm.watchAd()
        XCTAssertEqual(ad.shown, 1)
    }

    func testFailSheetButtonSaysLoadingUntilTheFirstLoadFails() async {
        let ad = FakeRewarded(ready: false)
        let vm = makeVM(store: store(run: lastPickRun()), ads: AdServices(rewarded: ad))
        await toFailSheet(vm)
        XCTAssertEqual(vm.adButtonState, .loading)
        ad.loadFailed = true
        XCTAssertEqual(vm.adButtonState, .failed)
        ad.loadFailed = false
        ad.isReady = true
        XCTAssertEqual(vm.adButtonState, .ready)
    }

    func testALateRewardAfterATimeoutStillGrantsThePicks() async {
        let ad = FakeRewarded(ready: true)
        let vm = makeVM(store: store(run: lastPickRun()), ads: AdServices(rewarded: ad))
        await toFailSheet(vm)
        vm.watchAd()
        ad.finish(.failed)                            // the manager's watchdog released the game
        XCTAssertEqual(vm.sheet, .fail)
        XCTAssertEqual(vm.run.picks, 0)
        ad.finishLate(.rewarded)                      // ...but the ad appeared and the player watched it
        XCTAssertEqual(vm.run.picks, 2)
        XCTAssertTrue(vm.run.adUsed)
    }

    func testRewardedReadyStateIsMirroredFromTheManagerAtStart() {
        let ad = FakeRewarded(ready: true)
        let vm = makeVM(store: SaveStore(url: nil), ads: AdServices(rewarded: ad))
        XCTAssertTrue(vm.rewardedReady)
        ad.isReady = false
        XCTAssertFalse(vm.rewardedReady)
    }

    func testReleaseStyleServicesWithoutAnAdNeverShowTheMock() async {
        let vm = makeVM(store: store(run: lastPickRun()), ads: .none)
        await toFailSheet(vm)
        XCTAssertFalse(vm.canWatchAd)
        vm.watchAd()
        XCTAssertFalse(vm.adPlaying)
        XCTAssertEqual(vm.sheet, .fail)
    }

    func testAbandonAndModeSwitchAreBlockedWhileTheAdIsUp() async {
        let ad = FakeRewarded(ready: true)
        let vm = makeVM(store: store(run: lastPickRun()), ads: AdServices(rewarded: ad))
        await toFailSheet(vm)
        vm.watchAd()
        vm.abandon()                                  // blocked while an ad is up
        vm.endRun()
        vm.switchMode(.daily)
        XCTAssertTrue(vm.adPlaying)
        XCTAssertEqual(vm.mode, .free)
        ad.finish(.rewarded)
        XCTAssertEqual(vm.run.picks, 2)
    }

    // MARK: - Interstitial

    /// Finishes a run the player ends from the fail sheet; returns the interstitial shown count after it.
    private func finishRun(store s: SaveStore, ad: FakeInterstitial, daily: Bool = false, attempt: Int = 1) async -> GameViewModel {
        s.update {
            let r = self.lastPickRun(daily: daily, attempt: attempt)
            if daily { $0.runs.daily = r; $0.mode = .daily } else { $0.runs.free = r; $0.mode = .free }
        }
        let vm = makeVM(store: s, ads: AdServices(interstitial: ad))
        await toFailSheet(vm)
        vm.endRun()
        return vm
    }

    func testInterstitialShowsOnTheThirdFinishedRunThenResetsTheCounter() async {
        let s = SaveStore(url: nil)
        let ad = FakeInterstitial()
        for n in 1...2 {
            let vm = await finishRun(store: s, ad: ad)
            XCTAssertEqual(vm.sheet, .result, "run \(n): no ad")
            XCTAssertEqual(ad.shown, 0)
        }
        XCTAssertEqual(s.data.runsSinceInterstitial, 2)

        let vm = await finishRun(store: s, ad: ad)
        XCTAssertEqual(ad.shown, 1)
        XCTAssertNotEqual(vm.sheet, .result, "the result sheet waits for the ad")
        XCTAssertTrue(vm.adPlaying)
        XCTAssertFalse(vm.canInteract)
        XCTAssertEqual(s.data.runsSinceInterstitial, 3, "reset only once the ad really appeared")

        ad.close()
        XCTAssertEqual(s.data.runsSinceInterstitial, 0)
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertFalse(vm.adPlaying)

        let next = await finishRun(store: s, ad: ad)
        XCTAssertEqual(next.sheet, .result, "the next run is back to counting")
        XCTAssertEqual(ad.shown, 1)
    }

    func testInterstitialNotLoadedIsSkippedSilentlyAndStaysDue() async {
        let s = SaveStore(url: nil)
        s.update { $0.runsSinceInterstitial = 2 }
        let ad = FakeInterstitial(ready: false)
        let vm = await finishRun(store: s, ad: ad)
        XCTAssertEqual(vm.sheet, .result, "result appears immediately")
        XCTAssertEqual(ad.shown, 0)
        XCTAssertFalse(vm.adPlaying)
        XCTAssertEqual(s.data.runsSinceInterstitial, 3, "still due: shows on the next run once loaded")

        ad.isReady = true
        let next = await finishRun(store: s, ad: ad)
        XCTAssertEqual(ad.shown, 1)
        XCTAssertTrue(next.adPlaying)
    }

    func testInterstitialThatCouldNotBePresentedKeepsTheCounterDue() async {
        let s = SaveStore(url: nil)
        s.update { $0.runsSinceInterstitial = 2 }
        let ad = FakeInterstitial()
        let vm = await finishRun(store: s, ad: ad)
        XCTAssertEqual(ad.shown, 1)
        ad.close(shown: false)                        // presentation failed / timed out
        XCTAssertEqual(vm.sheet, .result, "the result sheet still appears")
        XCTAssertEqual(s.data.runsSinceInterstitial, 3)
    }

    func testAWonRunContinuingIntoEndlessCountsOnce() async {
        let s = SaveStore(url: nil)
        s.update { $0.runsSinceInterstitial = 0 }
        var r = lastPickRun()
        r.endless = true                              // the second result of a run that already won
        s.update { $0.runs.free = r; $0.mode = .free }
        let ad = FakeInterstitial()
        let vm = makeVM(store: s, ads: AdServices(interstitial: ad))
        await toFailSheet(vm)
        vm.endRun()
        XCTAssertEqual(vm.sheet, .result)
        XCTAssertEqual(s.data.runsSinceInterstitial, 0, "not counted again")
        XCTAssertEqual(ad.shown, 0)
    }

    func testNoInterstitialOnTheFirstDailyAttemptOfTheDay() async {
        let s = SaveStore(url: nil)
        s.update { $0.runsSinceInterstitial = 5 }       // long overdue
        let ad = FakeInterstitial()
        let first = await finishRun(store: s, ad: ad, daily: true, attempt: 1)
        XCTAssertEqual(first.sheet, .result)
        XCTAssertEqual(ad.shown, 0, "first daily attempt is never interrupted")

        let second = await finishRun(store: s, ad: ad, daily: true, attempt: 2)
        XCTAssertEqual(ad.shown, 1)
        XCTAssertTrue(second.adPlaying)
    }

    func testInterstitialWithoutAServiceNeverShows() async {
        let s = SaveStore(url: nil)
        s.update { $0.runsSinceInterstitial = 9 }
        s.update { $0.runs.free = self.lastPickRun(); $0.mode = .free }
        let vm = makeVM(store: s, ads: .none)
        await toFailSheet(vm)
        vm.endRun()
        XCTAssertEqual(vm.sheet, .result)
    }

    func testInterstitialCounterIsPersistedAndOldSavesDecode() throws {
        var d = SaveData()
        d.runsSinceInterstitial = 2
        let back = try JSONDecoder().decode(SaveData.self, from: JSONEncoder().encode(d))
        XCTAssertEqual(back.runsSinceInterstitial, 2)

        let old = try JSONDecoder().decode(SaveData.self, from: Data(#"{"unlock":2}"#.utf8))
        XCTAssertEqual(old.runsSinceInterstitial, 0)
        XCTAssertEqual(old.unlock, 2)
    }

    // MARK: - Banner

    func testBannerOnlyOnShopAndResultNeverOnTheMainScreen() async {
        XCTAssertFalse(AdPlacement.showsBanner(on: nil), "main screen")
        for sheet in [GameViewModel.Sheet.fail, .difficulty, .rules, .dashboard] {
            XCTAssertFalse(AdPlacement.showsBanner(on: sheet), "\(sheet)")
        }
        XCTAssertTrue(AdPlacement.showsBanner(on: .shop))
        XCTAssertTrue(AdPlacement.showsBanner(on: .result))

        let vm = makeVM(store: store(run: lastPickRun()), ads: AdServices(bannersEnabled: true))
        XCTAssertFalse(vm.bannerVisible, "main screen")
        await toFailSheet(vm)
        XCTAssertFalse(vm.bannerVisible, "fail sheet")
        vm.endRun()
        XCTAssertTrue(vm.bannerVisible, "result sheet")

        let off = makeVM(store: store(run: lastPickRun()), ads: .none)
        await toFailSheet(off)
        off.endRun()
        XCTAssertFalse(off.bannerVisible, "ads off")
    }

    // MARK: - Ad unit IDs

    func testDebugBuildsUseGoogleTestIDsOnly() {
        #if DEBUG
        XCTAssertEqual(AdConfig.rewarded, "ca-app-pub-3940256099942544/1712485313")
        XCTAssertEqual(AdConfig.interstitial, "ca-app-pub-3940256099942544/4411468910")
        XCTAssertEqual(AdConfig.banner, "ca-app-pub-3940256099942544/2435281174")
        XCTAssertEqual(AdConfig.appOpen, "ca-app-pub-3940256099942544/5575463023")
        for id in [AdConfig.rewarded, AdConfig.interstitial, AdConfig.banner, AdConfig.appOpen] {
            XCTAssertFalse(id.contains("9275380963550837"), "no real ID in Debug")
        }
        #endif
    }

    func testPlaceholderIsNeverAValidUnitID() {
        XCTAssertFalse(AdConfig.isValidUnitID(AdConfig.interstitialPlaceholder))
        XCTAssertFalse(AdConfig.isValidUnitID("ca-app-pub-9275380963550837/XXXXXXXXXX"))
        XCTAssertFalse(AdConfig.isValidUnitID(""))
        XCTAssertTrue(AdConfig.isValidUnitID("ca-app-pub-9275380963550837/5616789182"))
        XCTAssertTrue(AdConfig.isValidUnitID("ca-app-pub-3940256099942544/4411468910"))
    }

    func testUnitTestHostSuppressesAds() {
        XCTAssertTrue(AdConfig.suppressed)
    }

    // MARK: - Synthesized sounds

    func testEverySoundRendersFiniteAudibleSamplesWithoutClipping() {
        for sfx in Sfx.all {
            let s = SynthSounds.render(sfx)
            XCTAssertGreaterThan(s.count, 1000, "\(sfx)")
            XCTAssertTrue(s.allSatisfy { $0.isFinite && abs($0) <= 1 }, "\(sfx)")
            XCTAssertGreaterThan(s.map { abs($0) }.max() ?? 0, 0.01, "\(sfx) is audible")
            XCTAssertLessThan(Double(s.count) / SynthSounds.sampleRate, 1.2, "\(sfx) is short")
        }
    }

    func testSafePitchRisesWithTheStreakAndIsClamped() {
        let freqs = (1...9).map { SynthSounds.tones(for: .safe($0))[0].freq }
        XCTAssertEqual(freqs, freqs.sorted())
        XCTAssertEqual(Set(freqs).count, 9)
        XCTAssertEqual(SynthSounds.tones(for: .safe(0))[0].freq, freqs[0])
        XCTAssertEqual(SynthSounds.tones(for: .safe(40))[0].freq, freqs[8])
        XCTAssertEqual(SynthSounds.tones(for: .tick(2))[0].freq, 620 + 2 * 110)
    }

    /// `.began` without an `.ended` (iOS does not always send it): the next sound must bring the engine back.
    func testEngineRestartsOnTheNextSoundAfterAnInterruptionWithNoEnd() {
        let engine = SynthEngine()
        engine.restartThrottle = 0
        engine.start()
        engine.drain()
        let before = engine.restartAttempts

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        engine.drain()
        XCTAssertFalse(engine.isReady, "an interruption marks the engine not ready")

        engine.play(.coin)
        engine.drain()
        XCTAssertGreaterThan(engine.restartAttempts, before, "play tried to restart the engine without waiting for .ended")
    }

    func testRestartAttemptsAreThrottled() {
        let engine = SynthEngine()
        engine.restartThrottle = 60
        engine.start()
        engine.drain()
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        engine.drain()
        engine.play(.coin)
        engine.drain()
        let after = engine.restartAttempts
        for _ in 0..<5 { engine.play(.coin) }
        engine.drain()
        XCTAssertEqual(engine.restartAttempts, after, "no restart storm while sounds keep coming")
    }

    func testRenderingIsDeterministic() {
        XCTAssertEqual(SynthSounds.render(.boom), SynthSounds.render(.boom))
    }
}
