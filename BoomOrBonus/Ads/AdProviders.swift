//
//  AdProviders.swift
//  BoomOrBonus
//
//  What the view model needs from the ad managers, as protocols so tests can inject fakes
//  (02-screens-ux.md §12). A provider calls its completion exactly once, on the main actor, and never
//  leaves the caller waiting: a failed or stuck presentation completes with `.failed`.
//

import Foundation

enum RewardedOutcome: Equatable {
    case rewarded      // userDidEarnReward fired, then the ad closed
    case dismissed     // closed without the reward
    case failed        // could not be shown
}

@MainActor
protocol RewardedAdProviding: AnyObject {
    var isReady: Bool { get }
    /// True after a load failed, until one succeeds (the fail sheet then says the ad cannot be loaded, not "loading").
    var loadFailed: Bool { get }
    /// Called whenever `isReady` or `loadFailed` changes (load finished, load failed, ad used up or expired).
    var onReadyChange: ((Bool) -> Void)? { get set }
    /// `completion` runs once with the outcome. After a presentation timeout it runs with `.failed` so the game is released;
    /// if that ad then appears after all, it runs once more with `.rewarded` if the player earned the reward.
    func show(completion: @escaping (RewardedOutcome) -> Void)
}

@MainActor
protocol InterstitialAdProviding: AnyObject {
    var isReady: Bool { get }
    /// `completion(shown)` runs when the ad is closed (`shown` true), or at once / after a timeout when it could not
    /// be shown (`shown` false). It runs exactly once.
    func show(completion: @escaping (Bool) -> Void)
}

/// What a GameViewModel talks to. `mockRewarded` is the Debug-only 2.5 s stand-in used by UI tests (-noAds / -seed).
struct AdServices {
    var rewarded: RewardedAdProviding?
    var interstitial: InterstitialAdProviding?
    var bannersEnabled = false
    var mockRewarded = false

    static let none = AdServices()

    /// The app's services: the real managers, or (Debug) nothing / the mock when ads are suppressed.
    @MainActor
    static func current() -> AdServices {
        #if DEBUG
        if AdConfig.suppressed { return AdServices(mockRewarded: true) }
        #endif
        return AdServices(rewarded: RewardedAdManager.shared,
                          interstitial: InterstitialAdManager.shared,
                          bannersEnabled: true)
    }
}

/// 02 §12: banners only on the shop and the result sheet, never on the main screen.
enum AdPlacement {
    static func showsBanner(on sheet: GameViewModel.Sheet?) -> Bool {
        sheet == .shop || sheet == .result
    }
}
