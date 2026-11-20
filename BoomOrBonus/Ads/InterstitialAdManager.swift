//
//  InterstitialAdManager.swift
//  BoomOrBonus
//
//  The interstitial shown before the result sheet (02-screens-ux.md §12). It only loads when the unit ID
//  is a real one: while Release still has the placeholder, `isReady` stays false and nothing is shown.
//  `show` always completes: when the ad is closed, or at once when it cannot be shown, or after 15 s
//  if it never appeared. Delegate callbacks for any ad other than the one being presented are ignored.
//

import GoogleMobileAds
import UIKit

@MainActor
final class InterstitialAdManager: NSObject, InterstitialAdProviding, FullScreenContentDelegate {
    static let shared = InterstitialAdManager()

    var isReady: Bool {
        ad != nil && Date().timeIntervalSince(loadedAt ?? .distantPast) < Self.lifetime
    }

    private var ad: InterstitialAd?
    private var loadedAt: Date?
    private var isLoading = false
    private var backoff = LoadBackoff()
    private var retryTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var presenting: InterstitialAd?
    private var completion: ((Bool) -> Void)?
    private var released = false
    private var didPresent = false
    private let watchdog = PresentWatchdog()
    private static let lifetime: TimeInterval = 55 * 60      // interstitials expire after an hour

    override private init() {
        super.init()
        // Loading starts from ConsentManager once ads may be requested.
        if ConsentManager.shared.canRequestAds { load() }
    }

    func load() {
        guard ConsentManager.shared.canRequestAds, AdConfig.interstitialConfigured, ad == nil, !isLoading else { return }
        isLoading = true
        InterstitialAd.load(with: AdConfig.interstitial, request: Request()) { [weak self] loaded, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let loaded {
                    self.backoff.reset()
                    loaded.fullScreenContentDelegate = self
                    self.ad = loaded
                    self.loadedAt = Date()
                    self.scheduleExpiry(of: loaded)
                } else {
                    if let error { debugLog("Interstitial failed to load: \(error.localizedDescription)") }
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

    private func scheduleExpiry(of loaded: InterstitialAd) {
        expiryTask?.cancel()
        expiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.lifetime * 1_000_000_000))
            guard !Task.isCancelled, let self, self.ad === loaded, self.presenting == nil else { return }
            self.ad = nil
            self.loadedAt = nil
            self.load()
        }
    }

    func show(completion: @escaping (Bool) -> Void) {
        if self.completion != nil, released {          // an earlier presentation timed out and never appeared
            self.completion = nil
            presenting = nil
            released = false
        }
        guard self.completion == nil, isReady, let ad, let root = UIApplication.topViewController else {
            if self.completion == nil, self.ad != nil, !isReady { self.ad = nil; load() }     // expired: reload
            completion(false)
            return
        }
        self.completion = completion
        presenting = ad
        released = false
        didPresent = false
        watchdog.start(after: 15) { [weak self] in
            guard let self, let done = self.completion, !self.released else { return }
            self.released = true
            done(false)                     // the player is not kept waiting; the ad is still tracked if it appears
        }
        ad.present(from: root)
    }

    private func finish() {
        watchdog.cancel()
        let done = completion
        let wasReleased = released
        completion = nil
        presenting = nil
        released = false
        ad = nil
        loadedAt = nil
        expiryTask?.cancel()
        load()
        if !wasReleased { done?(didPresent) }
    }

    // MARK: FullScreenContentDelegate

    nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            guard let presenting = self.presenting, presenting === (ad as AnyObject) else { return }
            self.didPresent = true
            self.watchdog.cancel()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            guard let presenting = self.presenting, presenting === (ad as AnyObject) else { return }
            self.finish()
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            guard let presenting = self.presenting, presenting === (ad as AnyObject) else { return }
            self.finish()
        }
    }
}
