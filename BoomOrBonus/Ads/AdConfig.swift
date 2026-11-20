//
//  AdConfig.swift
//  BoomOrBonus
//
//  Every ad unit ID lives here. Debug builds only ever see Google's official test IDs;
//  the real IDs are compiled into Release builds only.
//

import Foundation

/// Console logging for the ad managers: Debug builds only.
@inline(__always) func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

enum AdConfig {
    /// Set while the real interstitial unit has not been created in AdMob yet.
    static let interstitialPlaceholder = "INTERSTITIAL_UNIT_ID_TODO"

    #if DEBUG
    static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    static let banner = "ca-app-pub-3940256099942544/2435281174"
    static let appOpen = "ca-app-pub-3940256099942544/5575463023"
    #else
    static let rewarded = "ca-app-pub-9275380963550837/5616789182"
    // TODO(release): create the interstitial unit in AdMob and replace INTERSTITIAL_UNIT_ID_TODO with its ID
    // ("ca-app-pub-9275380963550837/XXXXXXXXXX"). Until then Release never loads or shows an interstitial.
    static let interstitial = interstitialPlaceholder
    static let banner = "ca-app-pub-9275380963550837/2702683361"
    static let appOpen = "ca-app-pub-9275380963550837/4495279208"
    #endif

    /// A real-looking unit ID: `ca-app-pub-<16 digits>/<10 digits>`. The placeholder (or any typo) fails this.
    static func isValidUnitID(_ id: String) -> Bool {
        id.range(of: #"^ca-app-pub-\d{16}/\d{10}$"#, options: .regularExpression) != nil
    }

    /// False while the interstitial ID is still the placeholder: Release then skips the interstitial.
    static var interstitialConfigured: Bool { isValidUnitID(interstitial) }

    /// QA / UI tests: no ads at all with -seed or -noAds, or as the unit-test host (Debug only).
    /// `-testAds` (or `-umpEEA`) lifts -seed / -noAds so the QA hooks can be used together with Google's test ads
    /// (never in the unit-test host).
    static let suppressed: Bool = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if TestHost.isUnitTesting { return true }
        if args.contains("-testAds") || args.contains("-umpEEA") { return false }
        return args.contains("-seed") || args.contains("-noAds")
        #else
        return false
        #endif
    }()
}
