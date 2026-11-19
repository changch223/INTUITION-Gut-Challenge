//
//  GameFlowUITests.swift
//  BoomOrBonusUITests
//
//  Drives the main screen, shop, difficulty sheet and result sheet with the Debug launch hook
//  `-seed 20261116` (also suppresses the AppOpenAd) and `-noAds`. `-seed` uses save-qa.json (wiped at launch),
//  never the real save; `-qaSave` relaunches from that file. `-today 20261116` fixes the date so the daily
//  challenge does not depend on the clock. Extra hooks (`-stage`, `-shop`, `-daily`, ...)
//  are listed in Game/DebugHooks.swift.
//

import XCTest

final class GameFlowUITests: XCTestCase {

    private var lostTaps = 0

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(seed: String = "20261116", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-seed", seed, "-noAds", "-today", "20261116"] + extra
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
            if app.buttons["fail.end"].exists || app.buttons["shop.next"].exists
                || app.buttons["result.retry"].exists { return false }
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
            if app.buttons["shop.next"].exists {
                app.buttons["shop.next"].tap()
                continue
            }
            if app.buttons["result.retry"].exists { break }
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

    /// Number of pixels close to the peek tag colors (green 安全 / red 會爆) in the top quarter of a card.
    private func tagPixels(_ card: XCUIElement) -> Int {
        guard let cg = card.screenshot().image.cgImage else { return -1 }
        let w = cg.width, h = cg.height / 4
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let top = cg.cropping(to: CGRect(x: 0, y: 0, width: w, height: h)) else { return -1 }
        ctx.draw(top, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return -1 }
        let colors: [(Int, Int, Int)] = [(0x0F, 0xA5, 0x7C), (0xF0, 0x28, 0x4B)]
        var n = 0
        for i in 0..<(w * h) {
            let r = Int(data[i * 4]), g = Int(data[i * 4 + 1]), b = Int(data[i * 4 + 2])
            if colors.contains(where: { abs($0.0 - r) < 14 && abs($0.1 - g) < 14 && abs($0.2 - b) < 14 }) { n += 1 }
        }
        return n
    }

    func testPeekTagOnCards() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        let before = [tagPixels(app.buttons["card.0"]), tagPixels(app.buttons["card.1"])]
        XCTAssertEqual(before, [0, 0], "no tag colors before peeking")
        app.buttons["item.peek"].tap()
        XCTAssertTrue(app.buttons["card.0"].label.contains("透視"))
        sleep(2)
        // The tag is drawn on both cards, so it must be visible in pixels, not only in the label.
        for i in 0..<2 {
            XCTAssertGreaterThan(tagPixels(app.buttons["card.\(i)"]), 150, "peek tag visible on card.\(i)")
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "peek-armed"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Opens stage 2 (fog boss) through the debug hooks and checks the toast does not cover the banner.
    func testStageTwoToastDoesNotCoverBanner() throws {
        let app = launch(extra: ["-shop"])
        XCTAssertTrue(app.buttons["shop.next"].waitForExistence(timeout: 10))
        app.buttons["shop.next"].tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 3))
        let banner = app.descendants(matching: .any)["ruleBanner"]
        XCTAssertTrue(banner.exists)
        XCTAssertTrue(banner.label.contains("濃霧"))
        XCTAssertFalse(toast.frame.intersects(banner.frame), "toast \(toast.frame) covers banner \(banner.frame)")
        // The toast also stays clear of both cards and the bank button.
        for id in ["card.0", "card.1", "bank"] {
            XCTAssertFalse(toast.frame.intersects(app.buttons[id].frame), "toast covers \(id)")
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "stage2-toast"
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - Shop

    func testShopBuyRerollAndNextStage() throws {
        let app = launch(extra: ["-shop", "-coins", "10"])
        XCTAssertTrue(app.buttons["shop.next"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["shop.breakdown"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["shop.preview"].label.contains("濃霧"), "next-stage boss preview")
        let title0 = app.descendants(matching: .any)["shop.title"].label
        let slot0 = app.buttons["shop.blessing.0"].label

        // Buy an item (透視 $3), double tap: bought once.
        app.buttons["shop.item.peek"].doubleTap()
        XCTAssertTrue(app.buttons["shop.item.peek"].label.contains("有 2 個"), app.buttons["shop.item.peek"].label)
        XCTAssertNotEqual(app.descendants(matching: .any)["shop.title"].label, title0, "coins went down")

        // Reroll: shelf changes (a different first slot, or at least one slot differs).
        usleep(500_000)
        let slotsBefore = (0..<3).map { app.buttons["shop.blessing.\($0)"].label }
        app.buttons["shop.reroll"].tap()
        usleep(500_000)
        let slotsAfter = (0..<3).map { app.buttons["shop.blessing.\($0)"].label }
        XCTAssertNotEqual(slotsBefore, slotsAfter)
        _ = slot0

        app.buttons["shop.next"].tap()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["shop.next"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["ruleBanner"].label.contains("魔王"))
        // The bought peek is in the item bar: 2 peeks (1 start + 1 bought).
        XCTAssertTrue(app.buttons["item.peek"].label.contains("2 個"), app.buttons["item.peek"].label)
    }

    /// Kill and relaunch: `-qaSave` (no `-seed`) re-opens save-qa.json untouched, so the shop comes back as it was.
    func testShopSurvivesKillAndRelaunchWithQaSave() throws {
        let app = launch(extra: ["-shop", "-coins", "10"])
        XCTAssertTrue(app.buttons["shop.next"].waitForExistence(timeout: 10))
        app.buttons["shop.item.peek"].tap()
        usleep(500_000)
        app.buttons["shop.reroll"].tap()
        usleep(500_000)
        let slots = (0..<3).map { app.buttons["shop.blessing.\($0)"].label }
        let title = app.descendants(matching: .any)["shop.title"].label
        app.terminate()

        let again = XCUIApplication()
        again.launchArguments = ["-qaSave", "-noAds", "-today", "20261116"]
        again.launch()
        XCTAssertTrue(again.buttons["shop.next"].waitForExistence(timeout: 10), "shop reopens")
        XCTAssertEqual((0..<3).map { again.buttons["shop.blessing.\($0)"].label }, slots, "same shelf")
        XCTAssertEqual(again.descendants(matching: .any)["shop.title"].label, title)
        XCTAssertTrue(again.buttons["shop.item.peek"].label.contains("有 2 個"))
    }

    /// 02 §4.1: buying must not move the list (the sheet used to swap between a scrolling and a static variant).
    func testShopKeepsScrollPositionAfterPurchase() throws {
        let app = launch(extra: ["-shop", "-coins", "30"])
        XCTAssertTrue(app.buttons["shop.next"].waitForExistence(timeout: 10))
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "shop-top"
        top.lifetime = .keepAlways
        add(top)
        if !app.buttons["shop.item.peek"].isHittable {
            app.descendants(matching: .any)["shop.title"].swipeUp()
            usleep(600_000)
        }
        XCTAssertTrue(app.buttons["shop.item.peek"].isHittable, "item row reachable")
        let before = app.buttons["shop.item.peek"].frame.minY
        let shot1 = XCTAttachment(screenshot: app.screenshot())
        shot1.name = "shop-scrolled-before"
        shot1.lifetime = .keepAlways
        add(shot1)
        app.buttons["shop.item.peek"].tap()
        usleep(700_000)
        let shot2 = XCTAttachment(screenshot: app.screenshot())
        shot2.name = "shop-scrolled-after"
        shot2.lifetime = .keepAlways
        add(shot2)
        XCTAssertEqual(app.buttons["shop.item.peek"].frame.minY, before, accuracy: 2, "list did not jump")
        XCTAssertTrue(app.buttons["shop.item.peek"].label.contains("有 2 個"))
    }

    func testShopSlotBoughtShowsAsPurchased() throws {
        let app = launch(extra: ["-shop", "-coins", "30"])
        XCTAssertTrue(app.buttons["shop.blessing.0"].waitForExistence(timeout: 10))
        let before = app.buttons["shop.blessing.0"].label
        app.buttons["shop.blessing.0"].tap()
        usleep(400_000)
        let after = app.descendants(matching: .any)["shop.blessing.0"].label
        XCTAssertNotEqual(before, after)
        XCTAssertTrue(after.contains("已購買"), after)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "shop-bought"
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - Difficulty

    func testDifficultySheetLockedLevelsCannotBePicked() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["topbar.level"].waitForExistence(timeout: 10))
        app.buttons["topbar.level"].tap()
        XCTAssertTrue(app.buttons["difficulty.0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["difficulty.0"].isEnabled)
        for i in 1...5 {
            XCTAssertFalse(app.buttons["difficulty.\(i)"].isEnabled, "level \(i) is locked")
            XCTAssertTrue(app.buttons["difficulty.\(i)"].label.contains("解鎖"))
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "difficulty"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["difficulty.cancel"].tap()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["difficulty.0"].exists)
    }

    func testUnlockedLevelAsksBeforeAbandoningAndStartsNewRun() throws {
        // Stage 3 is a run in progress; unlock 2 makes levels 1 and 2 pickable.
        let app = launch(extra: ["-unlock", "2", "-stage", "3"])
        app.buttons["topbar.level"].tap()
        XCTAssertTrue(app.buttons["difficulty.2"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["difficulty.2"].isEnabled)
        XCTAssertFalse(app.buttons["difficulty.3"].isEnabled)
        // On a short screen the list scrolls: bring the level into view first.
        if !app.buttons["difficulty.2"].isHittable { app.buttons["difficulty.1"].swipeUp() }
        app.buttons["difficulty.2"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["difficulty.confirmText"].waitForExistence(timeout: 2))
        // The confirmation is pinned in the footer: fully on screen and tappable on any screen size (iPhone SE).
        let window = app.windows.firstMatch.frame
        for id in ["difficulty.confirmCancel", "difficulty.confirm"] {
            XCTAssertTrue(app.buttons[id].isHittable, id)
            XCTAssertTrue(window.contains(app.buttons[id].frame), "\(id) inside the screen")
        }
        XCTAssertTrue(window.contains(app.descendants(matching: .any)["difficulty.confirmText"].frame))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "difficulty-confirm"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["difficulty.confirmCancel"].tap()
        XCTAssertFalse(app.buttons["difficulty.confirm"].exists)
        app.buttons["difficulty.2"].tap()
        app.buttons["difficulty.confirm"].tap()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["topbar.level"].label.contains("老手"))
        XCTAssertTrue(app.staticTexts["第 1 關 / 6"].exists)
    }

    // MARK: - Result sheet, unlock, endless

    func testWinResultUnlocksAndContinuesIntoEndless() throws {
        let app = launch(extra: ["-stage", "6", "-shop"])
        XCTAssertTrue(app.buttons["result.endless"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["result.unlock"].exists, "level 0 cleared: unlock note")
        XCTAssertTrue(app.buttons["result.nextLevel"].exists)
        XCTAssertTrue(app.buttons["result.retry"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "result-win"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["result.endless"].tap()
        XCTAssertTrue(app.buttons["shop.next"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["shop.next"].label, "前往第 7 關")
        app.buttons["shop.next"].tap()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["無盡 第 7 關"].exists)
    }

    func testFailResultButtonMatrix() throws {
        let app = launch(extra: ["-stage", "3", "-fail"])
        XCTAssertTrue(app.buttons["result.retry"].waitForExistence(timeout: 10))
        for id in ["result.changeLevel", "result.new", "result.retry"] {
            XCTAssertTrue(app.buttons[id].isHittable, id)
        }
        XCTAssertFalse(app.buttons["result.endless"].exists)
        app.buttons["result.changeLevel"].tap()
        XCTAssertTrue(app.buttons["difficulty.cancel"].waitForExistence(timeout: 3))
        app.buttons["difficulty.cancel"].tap()
        XCTAssertTrue(app.buttons["result.retry"].waitForExistence(timeout: 3), "cancel returns to the result sheet")
        app.buttons["result.retry"].tap()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["第 1 關 / 6"].exists)
    }

    // MARK: - Bosses, rules, blessings on screen

    func testFogBossCoversOneCard() throws {
        let app = launch(extra: ["-stage", "2"])
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        let labels = [app.buttons["card.0"].label, app.buttons["card.1"].label]
        XCTAssertEqual(labels.filter { $0.contains("蓋住的牌") }.count, 1, "\(labels)")
        XCTAssertTrue(app.descendants(matching: .any)["ruleBanner"].label.contains("魔王"))
    }

    func testCrushBossHalvesScoreOnBoom() throws {
        let app = launch(extra: ["-stage", "6", "-value", "40", "-boomPair", "-shield", "0"])
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["ruleBanner"].label.contains("重壓"))
        app.buttons["card.0"].tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(toast.label.contains("分數減半"), toast.label)
        XCTAssertEqual(app.staticTexts["score"].label, "分數 20")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "crush-toast"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testGritToast() throws {
        let app = launch(extra: ["-blessings", "grit", "-streak", "4", "-boomPair", "-shield", "0"])
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        app.buttons["card.0"].tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(toast.label.contains("不屈發動：連中 4 → 2"), toast.label)
        let banner = app.descendants(matching: .any)["ruleBanner"]
        XCTAssertFalse(toast.frame.intersects(banner.frame))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "grit-toast"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testDefuseToastAndChips() throws {
        let app = launch(extra: ["-blessings", "defuse,add,add", "-boomPair", "-shield", "0"])
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["祝福 加碼 2 層"].exists || app.descendants(matching: .any)["祝福 加碼 2 層"].exists)
        app.buttons["card.0"].tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(toast.label.contains("拆彈"), toast.label)
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

    // MARK: - Daily challenge (Phase 4)

    private func chipLabel(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any)["topbar.day"].label
    }

    private func cardState(_ app: XCUIApplication) -> [String] {
        [app.buttons["card.0"].label, app.buttons["card.1"].label,
         app.descendants(matching: .any)["picks"].label]
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Plays on (higher danger first, through shops) until the out-of-picks panel shows.
    private func playUntilFailSheet(_ app: XCUIApplication) {
        var n = 0
        while !app.buttons["fail.end"].exists, n < 150 {
            n += 1
            if app.buttons["shop.next"].exists { app.buttons["shop.next"].tap(); continue }
            if app.buttons["result.retry"].exists { return }
            let d0 = danger(of: app.buttons["card.0"].label)
            let d1 = danger(of: app.buttons["card.1"].label)
            _ = pick(app, d1 > d0 ? 1 : 0)
            _ = app.buttons["fail.end"].waitForExistence(timeout: 0.3)
        }
    }

    /// Taps ? and waits for the menu. A tap swallowed right after launch is recorded (not hidden) and retried once.
    private func openMenu(_ app: XCUIApplication) {
        app.buttons["topbar.menu"].tap()
        if !app.buttons["menu.close"].waitForExistence(timeout: 2) {
            lostTaps += 1
            print("LOST TAP on topbar.menu hittable=\(app.buttons["topbar.menu"].isHittable)")
            app.buttons["topbar.menu"].tap()
        }
        XCTAssertTrue(app.buttons["menu.close"].waitForExistence(timeout: 3), "menu opens")
    }

    func testSwitchToDailyAndBackKeepsBothRuns() throws {
        // A free seed other than today's date, or both modes would deal the same deck.
        let app = launch(seed: "4242")
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mode.free"].isSelected)
        XCTAssertTrue(app.buttons["topbar.level"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["topbar.day"].exists)

        let freeStart = cardState(app)
        XCTAssertTrue(pick(app, 0))                       // one pick in free play (a shield may keep the hand count)
        let free = cardState(app)
        XCTAssertNotEqual(free, freeStart)

        app.buttons["mode.daily"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["mode.daily"].isSelected)
        XCTAssertEqual(chipLabel(app), "今日挑戰，11/16，第 1 次")
        XCTAssertFalse(app.buttons["topbar.level"].exists, "difficulty is free play only")
        let freshDaily = cardState(app)
        XCTAssertTrue(freshDaily[2].contains("剩 7 手"), freshDaily[2])
        screenshot(app, "daily-main")

        XCTAssertTrue(pick(app, 1))
        let daily = cardState(app)
        XCTAssertNotEqual(daily, freshDaily)
        XCTAssertNotEqual(daily, free)

        app.buttons["mode.free"].tap()
        XCTAssertTrue(app.buttons["topbar.level"].waitForExistence(timeout: 3))
        XCTAssertEqual(cardState(app), free, "free run is where it was left")
        app.buttons["mode.daily"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 3))
        XCTAssertEqual(cardState(app), daily, "daily run is where it was left")
        XCTAssertEqual(chipLabel(app), "今日挑戰，11/16，第 1 次", "switching is not an attempt")
    }

    func testDailyAbandonAdvancesAttemptThenFailResultCanBeCopied() throws {
        let app = launch(extra: ["-daily"])
        XCTAssertTrue(app.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 10))
        XCTAssertEqual(chipLabel(app), "今日挑戰，11/16，第 1 次")

        openMenu(app)
        XCTAssertEqual(app.buttons["menu.abandon"].label, "放棄（算一次）")
        XCTAssertTrue(app.buttons["menu.mute"].exists)
        app.buttons["menu.abandon"].tap()
        // The confirmation is inside the sheet (no system alert) and fully on screen.
        XCTAssertTrue(app.descendants(matching: .any)["menu.confirmText"].waitForExistence(timeout: 2))
        let window = app.windows.firstMatch.frame
        for id in ["menu.abandonCancel", "menu.abandonConfirm"] {
            XCTAssertTrue(app.buttons[id].isHittable, id)
            XCTAssertTrue(window.contains(app.buttons[id].frame), id)
        }
        screenshot(app, "menu-abandon-confirm")
        app.buttons["menu.abandonCancel"].tap()
        XCTAssertTrue(app.buttons["menu.abandon"].exists, "cancel goes back to the menu")
        XCTAssertEqual(chipLabel(app), "今日挑戰，11/16，第 1 次")
        app.buttons["menu.abandon"].tap()
        app.buttons["menu.abandonConfirm"].tap()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["menu.abandon"].exists)
        XCTAssertEqual(chipLabel(app), "今日挑戰，11/16，第 2 次", "abandoning, even with no pick made, counts")

        // Play attempt 2 to the end: the result sheet says so, explains the daily rule and copies.
        playUntilFailSheet(app)
        XCTAssertTrue(app.buttons["fail.end"].waitForExistence(timeout: 5))
        app.buttons["fail.end"].tap()
        XCTAssertTrue(app.buttons["result.retry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["result.dailyHint"].exists)
        XCTAssertTrue(app.buttons["result.copy"].exists)
        XCTAssertTrue(app.buttons["result.free"].exists)
        XCTAssertEqual(app.buttons["result.retry"].label, "再挑戰一次（第 3 次）")
        let share = app.descendants(matching: .any)["result.shareText"].label
        XCTAssertTrue(share.hasPrefix("INTUITION++ 11/16 今日挑戰\n第 2 次挑戰，止步第 "), share)
        XCTAssertTrue(share.contains("🟥"), share)
        screenshot(app, "daily-fail-result")
        app.buttons["result.copy"].tap()
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["toast"].label, "已複製戰績")
        XCTAssertEqual(app.buttons["result.copy"].label, "已複製")
        app.buttons["result.retry"].tap()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 3))
        XCTAssertEqual(chipLabel(app), "今日挑戰，11/16，第 3 次")
        XCTAssertLessThanOrEqual(lostTaps, 1)
    }

    func testDailyWinResult() throws {
        let app = launch(extra: ["-daily", "-stage", "6", "-shop"])
        XCTAssertTrue(app.buttons["result.endless"].waitForExistence(timeout: 10))
        for id in ["result.copy", "result.retry", "result.free"] {
            XCTAssertTrue(app.buttons[id].isHittable, id)
        }
        XCTAssertFalse(app.descendants(matching: .any)["result.dailyHint"].exists, "the explanation is for a fail")
        XCTAssertTrue(app.descendants(matching: .any)["result.shareText"].label
            .hasPrefix("INTUITION++ 11/16 今日挑戰\n第 1 次挑戰破關 · 總分 "))
        screenshot(app, "daily-win-result")
        app.buttons["result.free"].tap()
        XCTAssertTrue(app.buttons["topbar.level"].waitForExistence(timeout: 3), "去自由練習")
        XCTAssertTrue(app.buttons["mode.free"].isSelected)
    }

    func testMuteToggleInMenu() throws {
        let app = launch()
        openMenu(app)
        XCTAssertEqual(app.buttons["menu.mute"].label, "關閉音效")
        XCTAssertEqual(app.buttons["menu.abandon"].label, "放棄重來", "free play wording")
        app.buttons["menu.mute"].tap()
        XCTAssertEqual(app.buttons["menu.mute"].label, "開啟音效")
        app.buttons["menu.close"].tap()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(lostTaps, 1)
    }

    /// Kill and relaunch (`-qaSave`, no `-seed`): the daily run comes back in daily mode, same day.
    func testDailyRunResumesAfterRelaunchAndMidnightStartsANewDay() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        app.buttons["mode.daily"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 3))
        XCTAssertTrue(pick(app, 0))
        let daily = cardState(app)
        app.terminate()

        let again = XCUIApplication()
        again.launchArguments = ["-qaSave", "-noAds", "-today", "20261116"]
        again.launch()
        XCTAssertTrue(again.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 10), "opens in daily mode")
        XCTAssertTrue(again.buttons["mode.daily"].isSelected)
        XCTAssertEqual(cardState(again), daily, "same run, same pair, same picks left")
        XCTAssertEqual(again.descendants(matching: .any)["topbar.day"].label, "今日挑戰，11/16，第 1 次")
        again.terminate()

        // After midnight yesterday's unfinished run is void, and it is not an attempt: still attempt 1.
        let next = XCUIApplication()
        next.launchArguments = ["-qaSave", "-noAds", "-today", "20261117"]
        next.launch()
        XCTAssertTrue(next.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 10))
        XCTAssertEqual(next.descendants(matching: .any)["topbar.day"].label, "今日挑戰，11/17，第 1 次")
        XCTAssertTrue(next.descendants(matching: .any)["picks"].label.contains("剩 7 手"))
        next.terminate()

        // And going back to the 16th: that day was never counted, so the next attempt there is still 1.
        let back = XCUIApplication()
        back.launchArguments = ["-qaSave", "-noAds", "-today", "20261116"]
        back.launch()
        XCTAssertTrue(back.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 10))
        XCTAssertEqual(back.descendants(matching: .any)["topbar.day"].label, "今日挑戰，11/16，第 1 次")
    }

    /// 02 §11: the switch sits above the scrim, so it works with a sheet open; the shop is still there on return.
    func testModeSwitchWorksWithTheShopOpenAndTheShopComesBack() throws {
        let app = launch(seed: "4242", extra: ["-shop", "-coins", "10"])
        XCTAssertTrue(app.buttons["shop.next"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mode.daily"].isHittable, "switch is above the scrim")
        let title = app.descendants(matching: .any)["shop.title"].label
        let slots = (0..<3).map { app.buttons["shop.blessing.\($0)"].label }
        screenshot(app, "shop-with-mode-switch")

        app.buttons["mode.daily"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["shop.next"].exists, "the daily run has no shop open")
        XCTAssertTrue(app.buttons["card.0"].exists)

        app.buttons["mode.free"].tap()
        XCTAssertTrue(app.buttons["shop.next"].waitForExistence(timeout: 3), "the free-play shop is restored")
        XCTAssertEqual(app.descendants(matching: .any)["shop.title"].label, title)
        XCTAssertEqual((0..<3).map { app.buttons["shop.blessing.\($0)"].label }, slots, "same shelf")
    }

    func testFreePlayResultCanReachDailyThroughTheSwitch() throws {
        let app = launch(seed: "4242", extra: ["-stage", "3", "-fail"])
        XCTAssertTrue(app.buttons["result.retry"].waitForExistence(timeout: 10))
        app.buttons["mode.daily"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["result.retry"].exists)
        XCTAssertEqual(chipLabel(app), "今日挑戰，11/16，第 1 次")
    }

    /// 02 §2.1 / §9: the daily chip opens the difficulty sheet; a level starts free play, the daily run stays.
    func testDailyChipOpensDifficultyAndPickingALevelLandsInFreePlayWithTheDailyRunIntact() throws {
        let app = launch(seed: "4242", extra: ["-unlock", "2"])
        XCTAssertTrue(app.buttons["card.0"].waitForExistence(timeout: 10))
        XCTAssertTrue(pick(app, 0))                         // a free run in progress (twice: a shield may absorb one)
        XCTAssertTrue(pick(app, 0))
        app.buttons["mode.daily"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 3))
        XCTAssertTrue(pick(app, 1))
        let daily = cardState(app)

        XCTAssertTrue(app.buttons["topbar.day"].label.contains("11/16"))
        app.buttons["topbar.day"].tap()
        XCTAssertTrue(app.buttons["difficulty.1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["difficulty.1"].isEnabled)
        XCTAssertFalse(app.buttons["difficulty.3"].isEnabled)
        XCTAssertFalse(app.buttons["difficulty.0"].label.contains("目前"), "no current level while in the daily challenge")
        screenshot(app, "daily-chip-difficulty-sheet")
        app.buttons["difficulty.1"].tap()
        // The free run in progress is replaced: the sheet asks first, inside itself.
        XCTAssertTrue(app.descendants(matching: .any)["difficulty.confirmText"].waitForExistence(timeout: 2))
        app.buttons["difficulty.confirm"].tap()

        XCTAssertTrue(app.buttons["topbar.level"].waitForExistence(timeout: 3), "landed in free play")
        XCTAssertTrue(app.buttons["topbar.level"].label.contains("進階"))
        XCTAssertTrue(app.buttons["mode.free"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["picks"].label.contains("剩 7 手") ||
                      app.descendants(matching: .any)["picks"].label.contains("剩 6 手"), "a fresh free run")

        app.buttons["mode.daily"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["topbar.day"].waitForExistence(timeout: 3))
        XCTAssertEqual(cardState(app), daily, "the daily run is intact")
        XCTAssertEqual(chipLabel(app), "今日挑戰，11/16，第 1 次", "and nothing was counted")
    }
}
