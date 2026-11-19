//
//  OnboardingTests.swift
//  BoomOrBonusTests
//
//  Phase 5: the first-launch onboarding (02 §7) and the rules sheet plumbing in the view model.
//

import XCTest
@testable import BoomOrBonus

@MainActor
final class OnboardingTests: XCTestCase {

    private let instant: GameViewModel.Sleeper = { _ in await Task.yield() }
    private var tempURLs: [URL] = []

    override func tearDown() {
        for u in tempURLs { try? FileManager.default.removeItem(at: u) }
        tempURLs = []
        super.tearDown()
    }

    private func tempURL() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("save-\(UUID().uuidString).json")
        tempURLs.append(u)
        return u
    }

    private func makeVM(_ store: SaveStore, seed: UInt32? = nil, hooks: DebugHooks = DebugHooks(),
                        showsOnboarding: Bool = true) -> GameViewModel {
        GameViewModel(store: store, launchSeed: seed, hooks: hooks, sleeper: instant,
                      reduceMotion: { false }, feedbackEnabled: false, randomSeed: { 777 },
                      today: { 20261116 }, defaultMode: .daily, showsOnboarding: showsOnboarding)
    }

    func testStepsMatchTheSpec() {
        XCTAssertEqual(CoachStep.all.map(\.target), [.score, .cards, .meta, .items, .bank, .score])
        XCTAssertEqual(CoachStep.all.count, 6)
    }

    func testFirstLaunchShowsOnboardingAndBlocksTheGame() {
        let vm = makeVM(SaveStore(url: nil))
        XCTAssertEqual(vm.coachStep, 0)
        XCTAssertFalse(vm.canInteract, "taps cannot reach the cards, items or bank")
        XCTAssertFalse(vm.canSwitchMode)
        vm.pick(0)
        XCTAssertNil(vm.pickedIndex)
        XCTAssertFalse(vm.isLocked)
        vm.openRules()
        XCTAssertNil(vm.sheet)
    }

    func testNextWalksAllStepsAndTheLastOneFinishesAndSaves() {
        let url = tempURL()
        let store = SaveStore(url: url)
        let vm = makeVM(store)
        for step in 1..<CoachStep.all.count {
            vm.nextCoach()
            XCTAssertEqual(vm.coachStep, step)
            XCTAssertFalse(store.data.onboardingDone, "only finishing counts")
        }
        vm.nextCoach()
        XCTAssertNil(vm.coachStep)
        XCTAssertTrue(store.data.onboardingDone)
        XCTAssertTrue(SaveStore(url: url).data.onboardingDone, "written to disk")
        XCTAssertTrue(vm.canInteract)
    }

    func testSkipFinishesAndIsSaved() {
        let url = tempURL()
        let store = SaveStore(url: url)
        let vm = makeVM(store)
        vm.nextCoach()
        vm.skipCoach()
        XCTAssertNil(vm.coachStep)
        XCTAssertTrue(SaveStore(url: url).data.onboardingDone)
    }

    func testNotShownAgainAfterDoneOrSkip() {
        let url = tempURL()
        let first = makeVM(SaveStore(url: url))
        XCTAssertEqual(first.coachStep, 0)
        first.skipCoach()
        let second = makeVM(SaveStore(url: url))
        XCTAssertNil(second.coachStep, "the next launch")
        XCTAssertTrue(second.canInteract)
    }

    func testAnExistingSaveWithOnboardingDoneNeverShowsIt() {
        var data = SaveData()
        data.onboardingDone = true
        let url = tempURL()
        try? JSONEncoder().encode(data).write(to: url)
        XCTAssertNil(makeVM(SaveStore(url: url)).coachStep)
    }

    func testOldSavesWithoutTheFlagCountAsNotDone() throws {
        let url = tempURL()
        try Data("{}".utf8).write(to: url)
        let store = SaveStore(url: url)
        XCTAssertFalse(store.data.onboardingDone)
        XCTAssertEqual(makeVM(store).coachStep, 0)
    }

    func testReplayFromTheRulesPanelStartsAtStepOneAndCloses() {
        let store = SaveStore(url: nil)
        let vm = makeVM(store)
        vm.skipCoach()
        vm.openRules()
        XCTAssertEqual(vm.sheet, .rules)
        vm.replayOnboarding()
        XCTAssertNil(vm.sheet, "the panel closes")
        XCTAssertEqual(vm.coachStep, 0)
        vm.nextCoach()
        vm.skipCoach()
        XCTAssertNil(vm.coachStep)
        XCTAssertTrue(store.data.onboardingDone)
    }

    func testReplayOnlyFromTheRulesPanel() {
        let vm = makeVM(SaveStore(url: nil))
        vm.skipCoach()
        vm.replayOnboarding()
        XCTAssertNil(vm.coachStep)
    }

    func testQaSeedLaunchSkipsOnboardingUnlessAsked() {
        let plain = makeVM(SaveStore(url: nil), seed: 20261116)
        XCTAssertNil(plain.coachStep)
        XCTAssertTrue(plain.canInteract)

        var hooks = DebugHooks()
        hooks.onboarding = true
        let store = SaveStore(url: nil)
        let asked = makeVM(store, seed: 20261116, hooks: hooks, showsOnboarding: false)
        XCTAssertEqual(asked.coachStep, 0)
        XCTAssertFalse(store.data.onboardingDone)
        asked.skipCoach()
        XCTAssertTrue(store.data.onboardingDone)
    }

    func testDefaultViewModelDoesNotShowOnboarding() {
        // Tests and previews build a view model without the app's `showsOnboarding`.
        XCTAssertNil(makeVM(SaveStore(url: nil), showsOnboarding: false).coachStep)
    }

    func testNoOnboardingOverARestoredShop() {
        // A save that was in the shop: the sheet comes first, the onboarding does not cover it.
        let store = SaveStore(url: nil)
        var r = GameEngine.newRun(seed: 5, lv: 0, mode: .free)
        r.value = GameEngine.target(r)
        r.picks = 3
        GameEngine.clearStage(&r)
        store.update { $0.runs.free = r; $0.mode = .free }
        let vm = makeVM(store)
        XCTAssertEqual(vm.sheet, .shop)
        XCTAssertNil(vm.coachStep)
    }

    func testQuestionMarkOpensTheRulesPanelAndAbandonWorksThere() {
        let vm = makeVM(SaveStore(url: nil), showsOnboarding: false)
        vm.openRules()
        XCTAssertEqual(vm.sheet, .rules)
        vm.closeRules()
        XCTAssertNil(vm.sheet)

        vm.openRules()
        let attempt = vm.run.attempt
        vm.abandon()
        XCTAssertNil(vm.sheet)
        XCTAssertEqual(vm.run.attempt, attempt + 1, "daily: abandon counts one attempt")
    }

    func testRulesPanelLevelButtonOpensTheDifficultySheet() {
        let vm = makeVM(SaveStore(url: nil), showsOnboarding: false)
        vm.openRules()
        vm.openDifficulty()
        XCTAssertEqual(vm.sheet, .difficulty)
    }

    func testItemsAreBlockedWhileTheOnboardingShows() {
        let vm = makeVM(SaveStore(url: nil))
        XCTAssertEqual(vm.coachStep, 0)
        let before = vm.run
        vm.useItem(.roll)
        vm.useItem(.peek)
        vm.useItem(.shield)
        XCTAssertEqual(vm.run, before)
        XCTAssertNil(vm.toast, "no shield hint under the scrim")
    }

    func testDebugHookParsesOnboarding() {
        #if DEBUG
        XCTAssertTrue(DebugHooks.parse(arguments: ["-seed", "1", "-onboarding"]).onboarding)
        XCTAssertFalse(DebugHooks.parse(arguments: ["-seed", "1"]).onboarding)
        #endif
    }
}
