//
//  AdsUITests.swift
//  BoomOrBonusUITests
//
//  Phase 7a: runs the app with Google's TEST ads (never real ones: Debug builds only know the test IDs).
//  `-seed` keeps the save in save-qa.json (the real save is untouched); `-testAds` lifts the ad suppression.
//  These need network access and a test ad fill, so they are NOT part of the GameFlowUITests suite;
//  run them on purpose:  -only-testing:BoomOrBonusUITests/AdsUITests
//  `TEST_RUNNER_SHOTS_DIR=<dir>` also saves each screenshot as a PNG there (like GameFlowUITests).
//

import XCTest

final class AdsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = LocaleArgs.zhHant + ["-seed", "20261116", "-testAds", "-today", "20261116"] + extra
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let s = app.screenshot()
        let att = XCTAttachment(screenshot: s)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        if let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] {
            let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "sim"
            let safe = "\(device)-\(name)".replacingOccurrences(of: " ", with: "_")
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(safe + ".png"))
        }
    }

    /// Boom pair on a 1-pick stage: one tap and the fail sheet is up.
    private func toFailSheet(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        app.buttons["card.0"].tap()
        XCTAssertTrue(app.buttons["fail.end"].waitForExistence(timeout: 10))
    }

    /// The covered game still shows up in the hierarchy, so "the ad is gone" means a game control is hittable again.
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable { return true }
            usleep(500_000)
        }
        return false
    }

    /// Closes a full-screen test ad through its labelled "Close" button (it exists as soon as the ad can be closed).
    private func tapClose(_ app: XCUIApplication, timeout: TimeInterval = 60) -> Bool {
        let close = app.buttons["Close"]
        guard close.waitForExistence(timeout: timeout) else { return false }
        close.tap()
        return true
    }

    func testRewardedTestAdGivesTwoPicks() throws {
        let app = launch(extra: ["-stage", "1", "-picks", "1", "-boomPair", "-shield", "0"])
        toFailSheet(app)
        let adButton = app.buttons["fail.ad"]
        // The test ad loads in the background; the button enables itself when it is ready.
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: adButton)
        waitForExpectations(timeout: 30)
        shot(app, "01-fail-sheet-ad-ready")
        adButton.tap()
        sleep(4)
        shot(app, "02-rewarded-test-ad")

        // The reward notice ("報酬を獲得しました" in the simulator's locale) appears when the video ends.
        let notice = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS '報酬' OR label CONTAINS[c] 'reward' OR label CONTAINS '獎勵' OR label CONTAINS '奖励'")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 90), "no reward notice from the test ad")
        XCTAssertTrue(tapClose(app), "no Close button on the rewarded test ad")
        XCTAssertTrue(waitUntilHittable(app.buttons["card.0"], timeout: 15), "game not back after closing the ad")
        let picks = app.descendants(matching: .any)["picks"]
        XCTAssertTrue(picks.label.contains("剩 2 手"), "picks label: \(picks.label)")
        shot(app, "03-after-rewarded")
    }

    func testInterstitialAfterThirdRunAndResultBanner() throws {
        // Counter at 2: the next finished run is the third. Free play, so no first-daily exemption.
        let app = launch(extra: ["-stage", "1", "-picks", "1", "-boomPair", "-shield", "0", "-adCounter", "2"])
        toFailSheet(app)
        sleep(15)                                       // a cold start needs a while to load the interstitial
        app.buttons["fail.end"].tap()
        // The result sheet waits for the interstitial.
        sleep(5)
        XCTAssertFalse(app.buttons["result.retry"].exists, "result sheet must not show while the interstitial is up")
        shot(app, "04-interstitial-test-ad")
        XCTAssertTrue(tapClose(app, timeout: 60), "no Close button on the interstitial test ad")
        XCTAssertTrue(waitUntilHittable(app.buttons["result.retry"], timeout: 15), "result sheet did not appear after the ad")
        let strip = app.descendants(matching: .any)["banner.strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10), "no banner strip on the result sheet")
        sleep(6)
        shot(app, "05-result-sheet-banner")
        // At least 24 pt between the strip and the nearest button.
        // The ad is the bottom 50 pt of the strip (adaptive banners are 50 pt tall on an iPhone).
        let button = app.buttons["result.retry"].frame
        XCTAssertGreaterThanOrEqual(strip.frame.maxY - 50 - button.maxY, 24, "banner too close to the buttons")
    }

    func testShopBannerKeepsItsDistanceFromTheButtons() throws {
        let app = launch(extra: ["-shop"])
        XCTAssertTrue(app.buttons["shop.next"].waitForExistence(timeout: 10))
        let strip = app.descendants(matching: .any)["banner.strip"]
        sleep(8)
        shot(app, "06-shop-banner")
        XCTAssertTrue(strip.waitForExistence(timeout: 10), "no banner strip in the shop")
        let next = app.buttons["shop.next"].frame
        XCTAssertLessThanOrEqual(strip.frame.maxY, app.frame.maxY + 0.5, "strip must be on screen")
        XCTAssertGreaterThanOrEqual(strip.frame.maxY - 50 - next.maxY, 24, "banner too close to the buttons")
        XCTAssertTrue(app.buttons["shop.next"].isHittable)
    }

    /// The result sheet's buttons are pinned: with the banner strip showing (iPhone SE: little room) the primary
    /// actions of a daily win are hittable without scrolling, and above the strip.
    func testDailyWinResultButtonsAreVisibleWithTheBannerShowing() throws {
        let app = launch(extra: ["-daily", "-stage", "6", "-shop"])
        let retry = app.buttons["result.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10), "no win result sheet")
        let strip = app.descendants(matching: .any)["banner.strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 30), "no banner strip")
        sleep(5)
        shot(app, "09-daily-win-result-with-banner")
        XCTAssertTrue(retry.isHittable, "result.retry must be hittable without scrolling")
        XCTAssertTrue(app.buttons["result.free"].isHittable, "result.free must be hittable without scrolling")
        XCTAssertLessThanOrEqual(app.buttons["result.free"].frame.maxY, strip.frame.minY, "buttons must sit above the strip")
        XCTAssertLessThanOrEqual(strip.frame.maxY, app.frame.maxY + 0.5, "strip must be on screen")
    }

    func testMainScreenHasNoBanner() throws {
        let app = launch(extra: [])
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        sleep(6)
        XCTAssertFalse(app.descendants(matching: .any)["banner.strip"].exists)
        shot(app, "07-main-screen-no-banner")
    }

    /// `-umpEEA` pretends to be in the EEA. The consent form only appears when a GDPR message is configured for
    /// this AdMob app (console setting); without one the form is skipped, which is also a valid outcome here.
    func testUMPFormWithEEAGeographyDoesNotBlockTheGame() throws {
        let app = XCUIApplication()
        app.launchArguments = LocaleArgs.zhHant + ["-seed", "20261116", "-umpEEA", "-today", "20261116"]
        app.launch()
        sleep(8)
        shot(app, "08-ump-eea")
        let consent = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'consent' OR label CONTAINS[c] 'accept' OR label CONTAINS[c] '同意'")).firstMatch
        if consent.exists { consent.tap() }
        XCTAssertTrue(waitUntilHittable(app.buttons["card.0"], timeout: 20), "game must stay usable")
    }
}
