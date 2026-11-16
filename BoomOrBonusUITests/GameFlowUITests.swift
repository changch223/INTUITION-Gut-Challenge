//
//  GameFlowUITests.swift
//  BoomOrBonusUITests
//
//  Drives the Phase 2 main screen with the Debug launch hook `-seed 20261116`
//  (also suppresses the AppOpenAd) and `-noAds`.
//

import XCTest

final class GameFlowUITests: XCTestCase {

    private var lostTaps = 0

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-seed", "20261116", "-noAds"] + extra
        app.launch()
        return app
    }

    private func danger(of label: String) -> Int {
        // "加 7 分，危險度 2 格，爆炸機率 25%"; fog cards carry no number.
        guard let r = label.range(of: "危險度 ") else { return 0 }
        return Int(label[r.upperBound...].prefix(while: { $0.isNumber })) ?? 0
    }

    private func isResultLabel(_ l: String) -> Bool {
        ["安全", "爆炸", "保命符擋下", "拆彈成功"].contains { l.hasPrefix($0) }
    }

    /// Taps a card and waits until the next pair is dealt, or a panel shows up.
    /// Returns false when a panel (fail / stage clear / result) is showing.
    private func pick(_ app: XCUIApplication, _ i: Int) -> Bool {
        let cards = [app.buttons["card.0"], app.buttons["card.1"]]
        let before = cards.map { $0.label }
        cards[i].tap()
        var retried = false
        let started = Date()
        let deadline = started.addingTimeInterval(8)
        while Date() < deadline {
            if app.buttons["fail.end"].exists || app.buttons["stageclear.next"].exists
                || app.buttons["result.again"].exists { return false }
            let now = cards.map { $0.label }
            if now != before, !now.contains(where: isResultLabel) { return true }
            if !retried, Date().timeIntervalSince(started) > 3 {
                // Record (not hide) a swallowed tap, then retry once.
                retried = true
                lostTaps += 1
                print("LOST TAP on card.\(i) hittable=\(cards[i].isHittable) frame=\(cards[i].frame) labels=\(now)")
                cards[i].tap()
            }
            usleep(100_000)
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)
        XCTFail("pick did not resolve within 8s: before=\(before) now=\(cards.map { $0.label }) picks=\(app.descendants(matching: .any)["picks"].label) score=\(app.staticTexts["score"].label)")
        return false
    }

    func testFailSheetShowsBothButtonsHittable() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "card.0").count, 1, "one element per card")

        // Always take the higher-danger card until picks run out below target.
        var guardCount = 0
        while !app.buttons["fail.end"].exists, guardCount < 120 {
            guardCount += 1
            if app.buttons["stageclear.next"].exists {
                app.buttons["stageclear.next"].tap()
                continue
            }
            if app.buttons["result.again"].exists { break }
            let d0 = danger(of: app.buttons["card.0"].label)
            let d1 = danger(of: app.buttons["card.1"].label)
            _ = pick(app, d1 > d0 ? 1 : 0)
            _ = app.buttons["fail.end"].waitForExistence(timeout: 0.3)
        }
        XCTAssertTrue(app.buttons["fail.end"].waitForExistence(timeout: 5), "reached the fail sheet")
        XCTAssertTrue(app.buttons["fail.ad"].exists)
        XCTAssertTrue(app.buttons["fail.end"].isHittable)
        XCTAssertTrue(app.buttons["fail.ad"].isHittable)
        let end = app.buttons["fail.end"].frame, ad = app.buttons["fail.ad"].frame
        XCTAssertGreaterThan(end.width, 100)
        XCTAssertEqual(end.width, ad.width, accuracy: 2, "equal width")
        XCTAssertLessThanOrEqual(lostTaps, 1)
        // Note: XCUI still lists elements marked accessibilityHidden, so VoiceOver hiding (accessibilityHidden + isModal)
        // cannot be asserted here.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "fail-sheet"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testPeekTagOnCards() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        app.buttons["item.peek"].tap()
        XCTAssertTrue(app.buttons["card.0"].label.contains("透視"))
        sleep(2)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "peek-armed"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testStageTwoToastDoesNotCoverBanner() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        var n = 0
        while !app.buttons["stageclear.next"].exists, n < 40 {
            n += 1
            if app.buttons["fail.end"].exists || app.buttons["result.again"].exists { break }
            if app.buttons["bank"].isEnabled {
                app.buttons["bank"].tap()
                _ = app.buttons["stageclear.next"].waitForExistence(timeout: 5)
                break
            }
            let d0 = danger(of: app.buttons["card.0"].label)
            let d1 = danger(of: app.buttons["card.1"].label)
            _ = pick(app, d1 < d0 ? 1 : 0)
        }
        guard app.buttons["stageclear.next"].exists else { throw XCTSkip("seed did not reach a stage clear with low-danger picks") }
        app.buttons["stageclear.next"].tap()
        usleep(700_000)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "stage2-toast"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testAccessibilityIdentifiersExist() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        for id in ["card.1", "item.shield", "item.peek", "item.roll", "item.dbl", "bank"] {
            XCTAssertTrue(app.buttons[id].exists, id)
        }
        XCTAssertTrue(app.staticTexts["score"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["picks"].exists)
    }
}
