# Release checklist: INTUITION++ 2.0 (build 2)

Things only the owner of the accounts can do before submitting. The app itself is feature complete (Phases 1 to 7b).

## 1. AdMob

- [x] **Interstitial ad unit.** Created in AdMob (2026-11-21); `ca-app-pub-9275380963550837/8255643279` is set in
      `BoomOrBonus/Ads/AdConfig.swift` (release block).
- [ ] **GDPR message.** In AdMob open Privacy & messaging, then European regulations, and create and **publish** a GDPR
      message for this app. Without a published message no consent form is ever shown (the simulator's `-umpEEA` hook
      cannot show one either), and the app loads no ads for EEA / UK users who have not consented.
- [ ] (Optional) add US state regulations messages if you want them; see the ATT decision in section 2.
- [ ] Check the app ID `ca-app-pub-9275380963550837~9068114885` and the three existing real units (rewarded, banner, app open) are the ones you want live.

## 2. App Store Connect

- [ ] **App Privacy label.** Fill it from what actually ships. The app's own `PrivacyInfo.xcprivacy` declares no tracking and
      no collected data (UserDefaults reason `CA92.1`). The bundled Google frameworks declare their own collection, and Apple
      expects the app's label to cover it. From `GoogleMobileAds.framework/PrivacyInfo.xcprivacy` and `UserMessagingPlatform.framework/PrivacyInfo.xcprivacy`
      (read from the Release build):

      | Data type | Linked to the user | Purposes | Source |
      |---|---|---|---|
      | Coarse Location | **Yes** | Third-Party Advertising, Analytics | Google Mobile Ads |
      | Device ID | **Yes** | Third-Party Advertising, Analytics | Google Mobile Ads (its manifest marks this type as used for tracking) |
      | Product Interaction | **Yes** | Third-Party Advertising, Analytics | Google Mobile Ads |
      | Advertising Data | **Yes** | Third-Party Advertising, Analytics | Google Mobile Ads |
      | Crash Data | No | Analytics | Google Mobile Ads |
      | Performance Data | No | Third-Party Advertising, Analytics | Google Mobile Ads |
      | Other Diagnostic Data | No | Third-Party Advertising, Analytics | Google Mobile Ads |

      The Google manifest also lists "Developer's Advertising or Marketing" for the types above; tick it too if App Store Connect offers it for your answers.
      UMP additionally lists Coarse Location, Performance Data and Product Interaction as App Functionality, not linked (consent form).
      The app has no ATT prompt, so the Device ID the SDK can read is the vendor ID (IDFV), not the advertising ID (IDFA).
      Re-check the table against Google's "Data disclosure" page (Google Mobile Ads SDK, iOS) for the exact SDK version in `Package.resolved` before submitting.

- [x] **DECIDED (2026-11-21): (a) no ATT prompt for 2.0.** Revisit (b) after launch based on ad revenue. Original decision note follows.
- **Tracking and ATT.** The Google manifest marks Device ID as used for tracking, so "Do you or your third-party partners use data for tracking?" must be answered consistently with how you configure ads. Choose one; the code does not implement either yet beyond (a):
      - **(a) Keep no ATT prompt (current build).** Ads are served without the IDFA (non-personalized in effect; the SDK falls back to the vendor ID and contextual signals). Answer the tracking question according to Google's guidance for apps that do not request ATT (follow the "Data disclosure" page; do not claim "no data collected").
        Trade-offs: no extra permission dialog, simplest review, no `NSUserTrackingUsageDescription`; lower ad revenue because personalization is limited.
      - **(b) Add an ATT prompt** (`NSUserTrackingUsageDescription` in `Info.plist`, `ATTrackingManager.requestTrackingAuthorization` after the UMP flow) for personalized ads.
        Trade-offs: higher eCPM when users allow it; an extra permission dialog on first launch (many users decline), a purpose string to write and localize in six languages, the privacy label must then state tracking, and review looks at the flow. Not implemented in this phase.
- [ ] **"Contains ads"** declaration (Pricing and Availability / App Information): answer yes.
- [ ] **Age rating** questionnaire: simulated gambling **none** (it is a card-pick game with no betting or prizes), no user generated content, no unrestricted web access; ads are served by Google AdMob.
- [ ] **Export compliance**: the app uses only standard iOS / system encryption (HTTPS): "No" for non-exempt encryption. (Also set `ITSAppUsesNonExemptEncryption = NO` in the Info.plist if you want App Store Connect to stop asking.)
- [ ] **URLs**: Support URL, Marketing URL (optional) and **Privacy Policy URL**. The privacy policy must mention Google Mobile Ads (data collected for advertising, the consent form, how to change consent).
- [ ] **`app-ads.txt`** on the developer website (the one listed as Marketing/Support URL domain), with the Google AdMob publisher line from AdMob > Settings > app-ads.txt (`google.com, pub-9275380963550837, DIRECT, f08c47fec0942fa0`). Lets AdMob verify the app.
- [ ] Paste the metadata of each language from `docs/redesign/store/<locale>.md` (name, subtitle, promotional text, description, keywords, What's New). `python3 docs/redesign/store/check-lengths.py` verifies the limits.
      Locale mapping: en = English (U.S.), ja = Japanese, ru = Russian, zh-Hans = Chinese (Simplified), zh-Hant = Chinese (Traditional), zh-HK = Chinese (Traditional, Hong Kong) if you add it as a separate localization (otherwise zh-Hant covers it).
- [ ] Upload the 6.9" screenshots from `docs/redesign/store/screenshots/<locale>/` (1320 x 2868, five per language). Re-take them from the real release flow if you change the UI.
- [ ] Support URL, marketing URL and privacy policy URL (the privacy policy must mention Google Mobile Ads).
- [ ] App Review notes (see section 5).

## 3. Device checks (qa/phase7a-manual-tests.md, section C)

Do these on a real iPhone with the Release or TestFlight build, not on the simulator:

- [ ] Real ad fill: rewarded and banner load and play (do not tap your own ads).
- [ ] Interstitial: appears every 3rd finished run once the unit ID above is in place.
- [ ] Hardware silent switch on: no game sound at all (`.ambient`).
- [ ] Music playing in the background: it is not interrupted, game sounds mix on top.
- [ ] Phone call / Siri during play: sounds come back afterwards, no crash.
- [ ] AirPods connect / disconnect during play: no crash, sound continues.
- [ ] Music app behaviour during and after an ad.
- [ ] Version shows 2.0 (build 2). Bump `CURRENT_PROJECT_VERSION` if build 2 was already uploaded.

Also from `qa/phase7b-manual-tests.md`: set the phone to each of the six languages and look through the screens once.

## 4. Archive and upload

- [ ] Product > Archive with the **Release** configuration (scheme BoomOrBonus), signing with the distribution profile.
- [ ] Validate, then Distribute App > App Store Connect > Upload.
- [ ] Wait for processing, answer export compliance (the app uses only standard iOS encryption: "No" for non-exempt encryption).

## 5. TestFlight and App Review

- [ ] Internal TestFlight: install on at least one device per size class (small iPhone, Pro Max) and repeat section 3.
- [ ] **App Review notes** (paste into App Store Connect):
      "INTUITION++ is a single player card game. No account or login is needed. The first launch shows a short tutorial.
      The game shows ads from Google AdMob: a banner in the shop and result screens, a rewarded ad that is optional (extra picks after a failed stage)
      and an interstitial between runs. In the EEA / UK a Google UMP consent form appears at first launch; the game is playable while it is shown.
      Settings (the ? button) has a 'Privacy settings' button where consent applies. There are no in-app purchases."
- [ ] Release: choose manual or automatic release after approval.

## 6. After release

- [ ] Delete nothing from `ScreenShoot/` (kept as the old style reference).
- [ ] Watch crash reports and the win-rate stats; the balance numbers are simulated (see 04-implementation-plan.md, section 6).
