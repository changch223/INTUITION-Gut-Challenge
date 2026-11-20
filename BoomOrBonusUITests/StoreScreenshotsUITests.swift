//
//  StoreScreenshotsUITests.swift
//  BoomOrBonusUITests
//
//  Reproducible App Store screenshots: five per language, from the Debug hooks, with `-noAds` so no test ad UI shows.
//  Run on an iPhone 17 Pro Max simulator (1320 x 2868, the 6.9" set → screenshots/) or an iPhone 17 Pro
//  simulator (1206 x 2622, the 6.1"/6.3" set → screenshots-6.3/) after
//    xcrun simctl status_bar <id> override --time 9:41 --batteryState discharging --batteryLevel 100 --wifiBars 3 --cellularBars 4 --operatorName ''
//
//    TEST_RUNNER_STORE_SHOTS=1 TEST_RUNNER_SHOTS_DIR=<dir> xcodebuild test ... -only-testing:BoomOrBonusUITests/StoreScreenshotsUITests
//
//  Files: <dir>/<locale>/1-main.png, 2-shop.png, 3-daily-result.png, 4-records.png, 5-boss.png.
//  Skipped unless TEST_RUNNER_STORE_SHOTS is set, so the normal suites never run it.
//

import XCTest

final class StoreScreenshotsUITests: XCTestCase {

    private var loc = LocalizationUITests.locales[0]

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SHOTS"] != nil, "store screenshots only on request")
    }

    func testStoreShotsEnglish() { shots(LocalizationUITests.locales[0]) }
    func testStoreShotsJapanese() { shots(LocalizationUITests.locales[1]) }
    func testStoreShotsRussian() { shots(LocalizationUITests.locales[2]) }
    func testStoreShotsSimplifiedChinese() { shots(LocalizationUITests.locales[3]) }
    func testStoreShotsTraditionalChinese() { shots(LocalizationUITests.locales[4]) }
    func testStoreShotsHongKong() { shots(LocalizationUITests.locales[5]) }

    private func shots(_ l: LocalizationUITests.Loc) {
        loc = l
        let base = ["-seed", "20261116", "-noAds", "-today", "20261116"]

        // 1. Main screen in the middle of a run.
        var app = launch(base + ["-stage", "3", "-value", "31", "-coins", "9", "-streak", "3", "-peeks", "1",
                                 "-blessings", "cool,hot,snow"])
        if app.buttons["card.0"].waitForExistence(timeout: 10) { settle(app); shot(app, "1-main") }
        app.terminate()

        // 2. Shop.
        app = launch(base + ["-shop", "-stage", "3", "-coins", "14", "-blessings", "add,cool"])
        if app.buttons["shop.next"].waitForExistence(timeout: 10) { settle(app); shot(app, "2-shop") }
        app.terminate()

        // 3. Daily challenge result with the share text (a win).
        app = launch(base + ["-daily", "-shop", "-stage", "6", "-blessings", "add,snow,hot"])
        if app.buttons["result.endless"].waitForExistence(timeout: 10) { settle(app); shot(app, "3-daily-result") }
        app.terminate()

        // 4. My records.
        app = launch(base + ["-stats", "sample"])
        if app.buttons["topbar.records"].waitForExistence(timeout: 10) {
            settle(app)
            app.buttons["topbar.records"].tap()
            if app.buttons["dash.close"].waitForExistence(timeout: 5) { shot(app, "4-records") }
        }
        app.terminate()

        // 5. A boss stage (Fog: one card is hidden).
        app = launch(base + ["-stage", "2", "-value", "14", "-coins", "12", "-streak", "2", "-blessings", "cool,hot,eye"])
        if app.buttons["card.0"].waitForExistence(timeout: 10) { settle(app); shot(app, "5-boss") }
        app.terminate()
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = LocaleArgs.args(language: loc.language, locale: loc.locale) + args
        app.launch()
        return app
    }

    /// Lets the start toast go away.
    private func settle(_ app: XCUIApplication) {
        let toast = app.descendants(matching: .any)["toast"]
        let end = Date().addingTimeInterval(6)
        while toast.exists && Date() < end { usleep(150_000) }
        usleep(500_000)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: screenshot)
        att.name = "\(loc.tag)/\(name)"
        att.lifetime = .keepAlways
        add(att)
        if let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] {
            let folder = URL(fileURLWithPath: dir).appendingPathComponent(loc.tag)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
        }
    }
}
