//
//  RewardedAdManager.swift
//  BoomOrBonus
//
//  The rewarded ad behind 「看廣告，多 2 手」 (02-screens-ux.md §12).
//  Loads in the background (retrying with back-off) and publishes readiness through `onReadyChange`.
//  The reward is reported only after `userDidEarnReward` and the ad being closed; a failed presentation
//  (or one that never appears) completes with `.failed`, so the game is never left waiting.
//  Delegate callbacks for any ad other than the one being presented are ignored.
//

import GoogleMobileAds
import UIKit

@MainActor
final class RewardedAdManager: NSObject, RewardedAdProviding, FullScreenContentDelegate {
    static let shared = RewardedAdManager()

    var onReadyChange: ((Bool) -> Void)?
    private var loadFailedFlag = false
    /// A load failed, or the consent check could not allow ads: the button says the ad cannot be loaded.
    var loadFailed: Bool { loadFailedFlag || ConsentManager.shared.failed }
    var isReady: Bool {
        ad != nil && Date().timeIntervalSince(loadedAt ?? .distantPast) < Self.lifetime
    }

    private var ad: RewardedAd?
    private var loadedAt: Date?
    private var isLoading = false
    private var backoff = LoadBackoff()
    private var retryTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?

    private var presenting: RewardedAd?
    private var completion: ((RewardedOutcome) -> Void)?
    private var released = false          // the caller was already told `.failed` (timeout)
    private var earned = false
    private let watchdog = PresentWatchdog()
    private static let lifetime: TimeInterval = 55 * 60      // loaded ads are reloaded well before they expire

    override private init() {
        super.init()
        // Loading starts from ConsentManager once ads may be requested; its state changes reach the UI through here.
        ConsentManager.shared.observe { [weak self] in self?.consentChanged() }
        if ConsentManager.shared.canRequestAds { load() }
    }

    private func consentChanged() {
        onReadyChange?(isReady)
    }

    func load() {
        guard ConsentManager.shared.canRequestAds, ad == nil, !isLoading else { return }
        isLoading = true
        RewardedAd.load(with: AdConfig.rewarded, request: Request()) { [weak self] loaded, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let loaded {
                    self.backoff.reset()
                    loaded.fullScreenContentDelegate = self
                    self.ad = loaded
                    self.loadedAt = Date()
                    self.loadFailedFlag = false
                    self.scheduleExpiry(of: loaded)
                    self.onReadyChange?(true)
                } else {
                    if let error { print("Rewarded ad failed to load: \(error.localizedDescription)") }
                    let changed = !self.loadFailedFlag
                    self.loadFailedFlag = true
                    if changed { self.onReadyChange?(false) }
                    self.scheduleRetry()
                }
            }
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        let delay = backoff.next()
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled { self?.load() }
        }
    }

    /// A loaded ad goes stale after `lifetime`: drop it (the button turns off) and load a fresh one.
    private func scheduleExpiry(of loaded: RewardedAd) {
        expiryTask?.cancel()
        expiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.lifetime * 1_000_000_000))
            guard !Task.isCancelled, let self, self.ad === loaded, self.presenting == nil else { return }
            self.discard()
        }
    }

    /// The ad is spent (shown, failed or expired): drop it, tell the UI, load the next one.
    private func discard() {
        let was = ad != nil
        ad = nil
        loadedAt = nil
        expiryTask?.cancel()
        if was { onReadyChange?(false) }
        load()
    }

    func show(completion: @escaping (RewardedOutcome) -> Void) {
        if self.completion != nil, released {          // an earlier presentation timed out and never appeared
            self.completion = nil
            presenting = nil
            released = false
        }
        guard self.completion == nil else { completion(.failed); return }     // one presentation at a time
        guard let ad, isReady, let root = UIApplication.topViewController else {
            if self.ad != nil, !isReady { discard() }
            completion(.failed)
            return
        }
        self.completion = completion
        presenting = ad
        released = false
        earned = false
        // The caller is released after 15 s without the ad appearing; if it appears later it is still tracked.
        watchdog.start(after: 15) { [weak self] in
            guard let self, let done = self.completion, !self.released else { return }
            self.released = true
            done(.failed)
        }
        ad.present(from: root) { [weak self] in
            Task { @MainActor in
                guard let self, self.presenting === ad else { return }
                self.earned = true
            }
        }
    }

    private func finish(_ outcome: RewardedOutcome) {
        watchdog.cancel()
        let done = completion
        let wasReleased = released
        completion = nil
        presenting = nil
        released = false
        discard()
        // After a timeout the caller already got `.failed`; only a reward is worth delivering again.
        if !wasReleased || outcome == .rewarded { done?(outcome) }
    }

    // MARK: FullScreenContentDelegate

    nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            guard let presenting = self.presenting, presenting === (ad as AnyObject) else { return }
            self.watchdog.cancel()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            guard let presenting = self.presenting, presenting === (ad as AnyObject) else { return }
            self.finish(.failed)
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            guard let presenting = self.presenting, presenting === (ad as AnyObject) else { return }
            self.finish(self.earned ? .rewarded : .dismissed)
        }
    }
}
