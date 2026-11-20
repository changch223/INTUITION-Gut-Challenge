//
//  LocalizationUITests.swift
//  BoomOrBonusUITests
//
//  Phase 7b locale sweep: for each of the six languages it launches the app with the Debug hooks and walks through
//  every screen (main, boss / rule banner, toasts, pills, shop, fail, results, difficulty, rules, the four
//  dashboard tabs, onboarding). Every screen is screenshotted and audited.
//
//  `TEST_RUNNER_SHOTS_DIR=<dir> xcodebuild test ...` also saves each screenshot as <dir>/<device>/<locale>/NN-name.png.
//
//  What the audit can and cannot prove:
//   - SwiftUI exposes the FULL text as the accessibility label even when it is drawn truncated, so truncation cannot be
//     read from a label or a frame (a Text fills the width it is offered). The audit therefore checks what is reliable:
//       1. no missing translation: en and ru labels contain no CJK; zh-Hans and ja contain no Traditional-only characters;
//       2. no label ends with an ellipsis (a hand-truncated string), except the known loading texts;
//       3. nothing is drawn outside the screen horizontally (an overflowing row, a chip that does not wrap);
//       4. sibling buttons of one row do not overlap.
//   - Visual truncation is judged on the saved screenshots (see docs/redesign/qa/phase7b-manual-tests.md).
//

import XCTest

final class LocalizationUITests: XCTestCase {

    struct Loc {
        let tag: String          // folder name
        let language: String     // -AppleLanguages
        let locale: String       // -AppleLocale
    }

    static let locales = [
        Loc(tag: "en", language: "en", locale: "en_US"),
        Loc(tag: "ja", language: "ja", locale: "ja_JP"),
        Loc(tag: "ru", language: "ru", locale: "ru_RU"),
        Loc(tag: "zh-Hans", language: "zh-Hans", locale: "zh_CN"),
        Loc(tag: "zh-Hant", language: "zh-Hant", locale: "zh_TW"),
        Loc(tag: "zh-HK", language: "zh-HK", locale: "zh_HK"),
    ]

    /// Characters that exist only in Traditional Chinese (the ja list leaves out characters Japanese shares).
    private static let hantOnly = Set("關戰紀錄廣擋數購還層過開這個們點戲變賣啟閉總歸續獎複覽麼請讓亂")
    /// Loading texts that really end with an ellipsis.
    private static let allowedEllipsis = ["Loading ad…", "広告を読み込み中…", "Загрузка рекламы…", "广告加载中…", "廣告載入中…"]

    private var loc = LocalizationUITests.locales[0]
    private var counter = 0
    private var failures: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    // MARK: - Tests (one per language so a failure names it)

    func testSweepEnglish() throws { sweep(Self.locales[0]) }
    func testSweepJapanese() throws { sweep(Self.locales[1]) }
    func testSweepRussian() throws { sweep(Self.locales[2]) }
    func testSweepSimplifiedChinese() throws { sweep(Self.locales[3]) }
    func testSweepTraditionalChinese() throws { sweep(Self.locales[4]) }
    func testSweepHongKong() throws { sweep(Self.locales[5]) }

    // MARK: - Sweep

    private func sweep(_ l: Loc) {
        loc = l
        counter = 0
        let base = ["-seed", "20261116", "-noAds", "-today", "20261116"]

        // 1. Main screen on a boss stage: banner, blessing chips, items, streak, boss toast.
        var app = launch(base + ["-stage", "2", "-coins", "12", "-streak", "3", "-peeks", "1",
                                 "-blessings", "cool,hot,snow,add,eye"])
        if app.descendants(matching: .any)["toast"].waitForExistence(timeout: 3) { shot(app, "main-boss-toast") }
        waitForToastToGo(app)
        shot(app, "main-boss")
        // Item toast and the dashboard pill-free state.
        if app.buttons["item.peek"].exists { app.buttons["item.peek"].tap(); _ = app.descendants(matching: .any)["toast"].waitForExistence(timeout: 2); shot(app, "toast-peek") }
        app.terminate()

        // 2. Rule banner (non-boss stage) with the target reached: bank button ready.
        app = launch(base + ["-stage", "3", "-value", "70", "-coins", "5"])
        _ = app.buttons["card.0"].waitForExistence(timeout: 8)
        waitForToastToGo(app)
        shot(app, "main-rule-target-reached")
        app.terminate()

        // 3. Daily challenge main screen (day chip), first pick marks.
        app = launch(base + ["-daily", "-streak", "2"])
        _ = app.buttons["card.0"].waitForExistence(timeout: 8)
        waitForToastToGo(app)
        shot(app, "main-daily")
        app.terminate()

        // 4. Shield toast and the shield reveal on a boom pair.
        app = launch(base + ["-stage", "1", "-shield", "2", "-boomPair"])
        if app.buttons["card.0"].waitForExistence(timeout: 8) {
            app.buttons["card.0"].tap()
            _ = app.descendants(matching: .any)["toast"].waitForExistence(timeout: 3)
            shot(app, "toast-shield")
        }
        app.terminate()

        // 5. A boom without a shield: crush boss on stage 6 (halved score toast).
        app = launch(base + ["-stage", "6", "-value", "40", "-shield", "0", "-boomPair"])
        if app.buttons["card.0"].waitForExistence(timeout: 8) {
            waitForToastToGo(app)
            app.buttons["card.0"].tap()
            _ = app.descendants(matching: .any)["toast"].waitForExistence(timeout: 3)
            shot(app, "toast-boom-crush")
        }
        app.terminate()

        // 6. New-record pill (stats with every record at 1, a safe pick with the Steady Hand blessing).
        app = launch(base + ["-stats", "low", "-blessings", "cool"])
        if app.buttons["card.0"].waitForExistence(timeout: 8) {
            waitForToastToGo(app)
            tapSafest(app)
            _ = app.descendants(matching: .any)["rec.pill"].waitForExistence(timeout: 3)
            shot(app, "pill-new-record")
        }
        app.terminate()

        // 7. Shop.
        app = launch(base + ["-shop", "-stage", "3", "-coins", "14", "-blessings", "add,snow"])
        if app.buttons["shop.next"].waitForExistence(timeout: 8) {
            shot(app, "shop-top")
            app.swipeUp()
            shot(app, "shop-scrolled")
        }
        app.terminate()
        app = launch(base + ["-shop", "-stage", "5", "-coins", "2", "-blessings", "add,snow,cool,hot,grit"])
        if app.buttons["shop.next"].waitForExistence(timeout: 8) { shot(app, "shop-full-blessings-boss-next") }
        app.terminate()

        // 8. Fail sheet and the losing result (free play).
        app = launch(base + ["-stage", "3", "-picks", "1", "-boomPair", "-shield", "0", "-blessings", "add,hot"])
        if app.buttons["card.0"].waitForExistence(timeout: 8) {
            waitForToastToGo(app)
            app.buttons["card.0"].tap()
            if app.buttons["fail.end"].waitForExistence(timeout: 8) {
                shot(app, "fail-sheet")
                app.buttons["fail.end"].tap()
                if app.buttons["result.retry"].waitForExistence(timeout: 8) {
                    shot(app, "result-lose-free")
                    app.swipeUp()
                    shot(app, "result-lose-free-scrolled")
                }
            }
        }
        app.terminate()

        // 9. Free-play win result (unlocks a difficulty) and the endless result.
        app = launch(base + ["-shop", "-stage", "6", "-blessings", "add,snow,hot"])
        if app.buttons["result.endless"].waitForExistence(timeout: 8) {
            shot(app, "result-win-free")
            app.swipeUp()
            shot(app, "result-win-free-scrolled")
        }
        app.terminate()

        // 10. Daily win and daily loss results (share text).
        app = launch(base + ["-daily", "-shop", "-stage", "6", "-blessings", "add,snow,hot"])
        if app.buttons["result.endless"].waitForExistence(timeout: 8) {
            shot(app, "result-win-daily")
        }
        app.terminate()
        app = launch(base + ["-daily", "-stage", "4", "-picks", "1", "-boomPair", "-shield", "0"])
        if app.buttons["card.0"].waitForExistence(timeout: 8) {
            waitForToastToGo(app)
            app.buttons["card.0"].tap()
            if app.buttons["fail.end"].waitForExistence(timeout: 8) {
                app.buttons["fail.end"].tap()
                if app.buttons["result.retry"].waitForExistence(timeout: 8) {
                    shot(app, "result-lose-daily")
                    app.buttons["result.copy"].tap()
                    shot(app, "result-lose-daily-copied")
                }
            }
        }
        app.terminate()

        // 11. Difficulty sheet.
        app = launch(base + ["-lv", "1", "-unlock", "3"])
        if app.buttons["topbar.level"].waitForExistence(timeout: 8) {
            waitForToastToGo(app)
            app.buttons["topbar.level"].tap()
            if app.buttons["difficulty.cancel"].waitForExistence(timeout: 5) {
                shot(app, "difficulty")
                app.swipeUp()
                shot(app, "difficulty-scrolled")
            }
        }
        app.terminate()

        // 12. Rules sheet (three scroll positions) and the abandon confirmation.
        app = launch(base)
        if app.buttons["topbar.menu"].waitForExistence(timeout: 8) {
            waitForToastToGo(app)
            app.buttons["topbar.menu"].tap()
            if app.buttons["rules.close"].waitForExistence(timeout: 5) {
                shot(app, "rules-1")
                app.swipeUp(); shot(app, "rules-2")
                app.swipeUp(); shot(app, "rules-3")
                app.swipeUp(); shot(app, "rules-4")
                app.buttons["rules.abandon"].tap()
                shot(app, "rules-abandon-confirm")
            }
        }
        app.terminate()

        // 13. My records: sample stats, four tabs.
        app = launch(base + ["-stats", "sample", "-legacySample"])
        if app.buttons["topbar.records"].waitForExistence(timeout: 8) {
            waitForToastToGo(app)
            app.buttons["topbar.records"].tap()
            if app.buttons["dash.close"].waitForExistence(timeout: 5) {
                shot(app, "dash-overview")
                app.swipeUp(); shot(app, "dash-overview-scrolled")
                for tab in ["daily", "levels", "blessings"] {
                    app.buttons["dash.tab.\(tab)"].tap()
                    shot(app, "dash-\(tab)")
                    if tab == "daily" { app.swipeUp(); shot(app, "dash-daily-scrolled") }
                }
            }
        }
        app.terminate()

        // 14. My records: empty state and the sample badge.
        app = launch(base)
        if app.buttons["topbar.records"].waitForExistence(timeout: 8) {
            waitForToastToGo(app)
            app.buttons["topbar.records"].tap()
            if app.buttons["dash.sample"].waitForExistence(timeout: 5) {
                shot(app, "dash-empty")
                app.buttons["dash.sample"].tap()
                shot(app, "dash-sample-badge")
            }
        }
        app.terminate()

        // 15. Onboarding, all six steps.
        app = launch(base + ["-onboarding"])
        for step in 1...6 {
            guard app.buttons["coach.next"].waitForExistence(timeout: 8) else { break }
            shot(app, "onboarding-\(step)")
            app.buttons["coach.next"].tap()
        }
        app.terminate()

        if !failures.isEmpty {
            XCTFail("\(loc.tag): \(failures.count) audit problem(s):\n" + failures.joined(separator: "\n"))
        }
    }

    // MARK: - Helpers

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = LocaleArgs.args(language: loc.language, locale: loc.locale) + args
        app.launch()
        return app
    }

    private func waitForToastToGo(_ app: XCUIApplication, timeout: TimeInterval = 5) {
        let toast = app.descendants(matching: .any)["toast"]
        let end = Date().addingTimeInterval(timeout)
        while toast.exists && Date() < end { usleep(150_000) }
    }

    /// Taps the card with the lower danger (the second-to-last number of its label: ... danger N, P%).
    private func tapSafest(_ app: XCUIApplication) {
        func danger(_ s: String) -> Int {
            let nums = s.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            return nums.count >= 2 ? nums[nums.count - 2] : 9
        }
        let a = app.buttons["card.0"].label, b = app.buttons["card.1"].label
        app.buttons[danger(a) <= danger(b) ? "card.0" : "card.1"].tap()
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        counter += 1
        let tag = String(format: "%02d-%@", counter, name)
        let screenshot = app.screenshot()
        let att = XCTAttachment(screenshot: screenshot)
        att.name = "\(loc.tag)/\(tag)"
        att.lifetime = .keepAlways
        add(att)
        if let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] {
            let device = (ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "sim").replacingOccurrences(of: " ", with: "_")
            let folder = URL(fileURLWithPath: dir).appendingPathComponent(device).appendingPathComponent(loc.tag)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: folder.appendingPathComponent(tag + ".png"))
        }
        audit(app, tag)
    }

    private func audit(_ app: XCUIApplication, _ tag: String) {
        guard let snapshot = try? app.snapshot() else { return }
        let screen = snapshot.frame
        var buttons: [(String, CGRect)] = []

        func walk(_ s: XCUIElementSnapshot) {
            let label = s.label
            let isText = s.elementType == .staticText || s.elementType == .button || s.elementType == .other
            if isText, !label.isEmpty {
                if let problem = textProblem(label) { record("\(tag): \(problem): “\(label.prefix(80))”") }
                let f = s.frame
                if f.width > 0, s.elementType != .other, f.minX < screen.minX - 1 || f.maxX > screen.maxX + 1 {
                    record("\(tag): drawn outside the screen (\(Int(f.minX))...\(Int(f.maxX))): “\(label.prefix(60))”")
                }
            }
            if s.elementType == .button, !s.identifier.isEmpty { buttons.append((s.identifier, s.frame)) }
            for c in s.children { walk(c) }
        }
        walk(snapshot)

        // Buttons of one screen must not overlap each other (cards and the bank button included).
        for i in 0..<buttons.count {
            for j in (i + 1)..<max(i + 1, buttons.count) {
                let a = buttons[i], b = buttons[j]
                if a.1.width > 0, b.1.width > 0, a.1.insetBy(dx: 2, dy: 2).intersects(b.1.insetBy(dx: 2, dy: 2)),
                   !a.0.hasPrefix("dash.tab"), !b.0.hasPrefix("dash.tab") {
                    record("\(tag): buttons overlap: \(a.0) \(a.1) / \(b.0) \(b.1)")
                }
            }
        }
    }

    private func textProblem(_ label: String) -> String? {
        let scalars = label.unicodeScalars
        let hasCJK = scalars.contains { (0x4E00...0x9FFF).contains($0.value) || (0x3040...0x30FF).contains($0.value) }
        switch loc.tag {
        case "en", "ru":
            if hasCJK { return "untranslated (CJK in \(loc.tag))" }
        case "zh-Hans", "ja":
            // 個 and 層 are Japanese too.
            let set = loc.tag == "ja" ? Self.hantOnly.subtracting("個層") : Self.hantOnly
            if label.contains(where: { set.contains($0) }) { return "Traditional-only characters in \(loc.tag)" }
        default: break
        }
        if (label.hasSuffix("…") || label.hasSuffix("...")) && !Self.allowedEllipsis.contains(where: { label.contains($0) }) {
            return "ends with an ellipsis"
        }
        return nil
    }

    private func record(_ message: String) {
        failures.append(message)
    }
}
