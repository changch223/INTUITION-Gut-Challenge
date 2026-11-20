//
//  ConsentManager.swift
//  BoomOrBonus
//
//  Google UMP consent (a certified CMP is required in the EEA, UK and Switzerland).
//  Ads are started and loaded only once `canRequestAds` is true. Gameplay never waits for this: any failure
//  (no network, no message configured, form error) leaves the game running without ads loaded. While consent is
//  unavailable `failed` is true (the fail sheet's ad button says the ad cannot be loaded), and the update is retried
//  whenever the app becomes active again, at most once per `retryInterval`.
//  The message itself (GDPR) is configured in the AdMob console, not here.
//  Debug only: `-umpEEA` makes the simulator look like it is in the EEA and resets the stored consent.
//

import Foundation
import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

/// What ConsentManager needs from UMP, as a protocol so tests can drive it with a fake.
@MainActor
protocol ConsentBackend: AnyObject {
    var canRequestAds: Bool { get }
    var privacyOptionsRequired: Bool { get }
    func requestUpdate(completion: @escaping (Error?) -> Void)
    func presentFormIfRequired(completion: @escaping (Error?) -> Void)
    func presentPrivacyOptions(completion: @escaping (Error?) -> Void)
}

@MainActor
final class UMPBackend: ConsentBackend {
    private var firstRequest = true

    var canRequestAds: Bool { UMPConsentInformation.sharedInstance.canRequestAds }
    var privacyOptionsRequired: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    func requestUpdate(completion: @escaping (Error?) -> Void) {
        let params = UMPRequestParameters()
        params.tagForUnderAgeOfConsent = false
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-umpEEA") {
            if firstRequest { UMPConsentInformation.sharedInstance.reset() }
            let debug = UMPDebugSettings()
            debug.geography = .EEA                 // simulators are debug devices automatically
            params.debugSettings = debug
        }
        #endif
        firstRequest = false
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: params) { error in
            Task { @MainActor in completion(error) }
        }
    }

    func presentFormIfRequired(completion: @escaping (Error?) -> Void) {
        UMPConsentForm.loadAndPresentIfRequired(from: UIApplication.topViewController) { error in
            Task { @MainActor in completion(error) }
        }
    }

    func presentPrivacyOptions(completion: @escaping (Error?) -> Void) {
        UMPConsentForm.presentPrivacyOptionsForm(from: UIApplication.topViewController) { error in
            Task { @MainActor in completion(error) }
        }
    }
}

@Observable
@MainActor
final class ConsentManager {
    static let shared = ConsentManager()

    /// Ads may be requested (the SDK is started and the managers load).
    private(set) var canRequestAds = false
    /// The rules sheet shows 「隱私設定」 only when the user has to be able to change their choice.
    private(set) var privacyOptionsRequired = false
    /// The consent check finished (or could not run) and ads still may not be requested.
    private(set) var failed = false

    @ObservationIgnored private let backend: ConsentBackend
    @ObservationIgnored private let enabled: Bool
    @ObservationIgnored private let retryInterval: TimeInterval
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let startAds: () -> Void
    @ObservationIgnored private var started = false
    @ObservationIgnored private var adsStarted = false
    @ObservationIgnored private var inFlight = false
    @ObservationIgnored private var lastAttempt = Date.distantPast
    @ObservationIgnored private var observers: [() -> Void] = []

    init(backend: ConsentBackend? = nil,
         enabled: Bool = !AdConfig.suppressed,
         retryInterval: TimeInterval = 30,
         now: @escaping () -> Date = { Date() },
         startAds: (() -> Void)? = nil) {
        self.backend = backend ?? UMPBackend()
        self.enabled = enabled
        self.retryInterval = retryInterval
        self.now = now
        self.startAds = startAds ?? {
            MobileAds.shared.start(completionHandler: nil)
            RewardedAdManager.shared.load()
            InterstitialAdManager.shared.load()
        }
    }

    /// The ad managers listen: their published state depends on consent (`failed`, `canRequestAds`).
    func observe(_ change: @escaping () -> Void) { observers.append(change) }

    /// Called once, when the game screen first appears. Does nothing when ads are suppressed (tests, -noAds, -seed).
    func start() {
        guard enabled, !started else { return }
        started = true
        // A previous session may already have gathered consent: start at once, and refresh below.
        if backend.canRequestAds { openAds() }
        runUpdate()
    }

    /// The app became active again: a consent check that failed (offline at launch...) is tried again, throttled.
    func appBecameActive() {
        guard enabled, started, !inFlight, !canRequestAds, now().timeIntervalSince(lastAttempt) >= retryInterval else { return }
        runUpdate()
    }

    /// The rules sheet's 「隱私設定」.
    func presentPrivacyOptions() {
        guard privacyOptionsRequired else { return }
        backend.presentPrivacyOptions { [weak self] error in
            if let error { NSLog("UMP privacy options failed: \(error.localizedDescription)") }
            self?.refresh()
        }
    }

    private func runUpdate() {
        guard !inFlight else { return }
        inFlight = true
        lastAttempt = now()
        backend.requestUpdate { [weak self] error in
            guard let self else { return }
            if let error {
                NSLog("UMP consent info update failed: \(error.localizedDescription)")
                self.finishUpdate()
                return
            }
            self.backend.presentFormIfRequired { [weak self] error in
                if let error { NSLog("UMP form failed: \(error.localizedDescription)") }
                self?.finishUpdate()
            }
        }
    }

    private func finishUpdate() {
        inFlight = false
        refresh()
    }

    private func refresh() {
        privacyOptionsRequired = backend.privacyOptionsRequired
        if backend.canRequestAds { openAds() }
        failed = !backend.canRequestAds
        observers.forEach { $0() }
    }

    private func openAds() {
        canRequestAds = true
        failed = false
        guard !adsStarted else { return }
        adsStarted = true
        startAds()
    }
}
