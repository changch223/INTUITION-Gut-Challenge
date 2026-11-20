//
//  GameScreen.swift
//  BoomOrBonus
//
//  The main screen (02-screens-ux.md §2). Everything is driven by GameViewModel;
//  this view only lays the pieces out and shows the sheets / toast / mock ad on top.
//

import SwiftUI

struct GameScreen: View {
    @State private var vm: GameViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// The banner strip's measured height (it is taken off the space the sheet may use); 73 until measured.
    @State private var bannerHeight: CGFloat = AdBannerStrip.estimatedHeight

    /// Space the sheet gives up: only while the strip really draws something (no consent yet, or a failed load, takes none).
    private var bannerReserve: CGFloat {
        vm.bannerVisible && ConsentManager.shared.canRequestAds && !AdConfig.suppressed ? bannerHeight : 0
    }

    init() {
        _vm = State(initialValue: GameViewModel.live)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            game
                .allowsHitTesting(vm.sheet == nil && !vm.adPlaying && vm.coachStep == nil)

            if vm.sheet != nil {
                Theme.deepNight.opacity(0.62)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)
                GeometryReader { geo in
                    // On an iPhone SE the navigation container is laid out about 5 pt past the bottom of the screen,
                    // so the sheet area is what is really on screen: the screen's bottom minus where the area starts.
                    let area = min(geo.size.height,
                                   UIScreen.main.bounds.height - geo.safeAreaInsets.bottom - geo.frame(in: .global).minY)
                    VStack(spacing: 0) {
                        Spacer(minLength: 58)          // room for the mode switch above the scrim
                        sheetContent
                            .environment(\.sheetMaxHeight, max(0, area - 58 - bannerReserve))
                        if vm.bannerVisible { AdBannerStrip(onTotalHeight: { bannerHeight = $0 }) }
                    }
                    .frame(width: geo.size.width, height: area)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                .accessibilityAddTraits(.isModal)
            }

            // 02 §11: the mode switch lives outside the sheets (prototype tabs), so it stays usable above the scrim.
            // It is only blocked while a pick or clear animation runs, or the mock ad plays.
            VStack(spacing: 0) {
                ModeSwitch(mode: vm.mode, enabled: vm.canSwitchMode, select: { vm.switchMode($0) })
                    .accessibilityHidden(vm.coachStep != nil)      // the onboarding is modal for VoiceOver too
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }

            if vm.adPlaying && vm.adIsMock {
                AdMockView(duration: vm.adDuration)
                    .transition(.opacity)
            }

            // The copy confirmation must be readable above the dimmed game.
            if let toast = vm.toast, toast.overSheet, vm.sheet != nil {
                VStack {
                    ToastView(text: toast.text)
                        .padding(.top, 6)
                        .id(toast.id)
                        .transition(.opacity)
                    Spacer()
                }
            }
        }
        // 02 §7: the onboarding sits above everything (mode switch, toast); targets are measured, not hard-coded.
        .overlayPreferenceValue(CoachTargetKey.self) { anchors in
            if let step = vm.coachStep {
                GeometryReader { geo in
                    CoachMarkOverlay(step: step,
                                     frames: anchors.mapValues { geo[$0] },
                                     size: geo.size,
                                     next: { vm.nextCoach() },
                                     skip: { vm.skipCoach() })
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: reduceMotion ? 0.1 : 0.25), value: vm.coachStep == nil)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            // Midnight, or the clock / time zone changed while the app stays in the foreground.
            vm.refreshDay()
        }
        .onChange(of: scenePhase) { _, phase in
            // 03 §2.1: back from the background after midnight, yesterday's daily run is void.
            if phase == .active {
                vm.refreshDay()
                ConsentManager.shared.appBecameActive()
            }
        }
        .animation(.easeOut(duration: 0.22), value: vm.toast)
        .animation(.easeOut(duration: reduceMotion ? 0.1 : 0.22), value: vm.recordPill)
        .onChange(of: vm.recordPill) { _, pill in
            // Not while a sheet covers the game: the player is somewhere else.
            if let pill, vm.sheet == nil { AccessibilityNotification.Announcement(pill.text).post() }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.32), value: vm.sheet)
        .animation(.easeOut(duration: 0.25), value: vm.adPlaying)
        .onChange(of: vm.toast) { _, toast in
            if let toast { AccessibilityNotification.Announcement(toast.text).post() }
        }
        .task { ConsentManager.shared.start() }      // UMP consent, then the ads SDK; never blocks the game
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .navigationBarHidden(true)
    }

    private var covered: Bool { vm.sheet != nil || vm.adPlaying || vm.coachStep != nil }

    /// Over the goal line and progress bar: never on the rule banner, the cards or the bank button.
    @ViewBuilder
    private var toastView: some View {
        if let toast = vm.toast, !toast.overSheet {
            ToastView(text: toast.text)
                .padding(.bottom, 2)
                .transition(.opacity.combined(with: reduceMotion ? .identity : .offset(y: -10)))
                .id(toast.id)
        }
    }

    /// 02 §6: the gold 「★ 新紀錄」 capsule under the score area (below the picks / streak row). It never takes a tap.
    @ViewBuilder
    private var pillView: some View {
        if let pill = vm.recordPill {
            Text(verbatim: pill.text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.goldText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.gold, in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
                .offset(y: 78)         // under the picks / streak row, over the blessings line
                .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.96)))
                .id(pill.id)
                .allowsHitTesting(false)
                .accessibilityIdentifier("rec.pill")
        }
    }

    // MARK: Game

    private var game: some View {
        VStack(spacing: 10) {
            Color.clear.frame(height: ModeSwitch.height)       // the switch itself is drawn above the scrim
            TopBar(run: vm.run, levelEnabled: vm.canInteract, openLevel: { vm.openDifficulty() },
                   menuEnabled: vm.canInteract, openMenu: { vm.openRules() },
                   recordsEnabled: vm.canInteract, openRecords: { vm.openDashboard() })
            RuleBanner(boss: vm.boss, mod: vm.mod)
            ScorePanel(value: vm.run.value, target: vm.target, stretch: vm.stretch, isFirstPick: vm.isFirstPick)
                .coachTarget(.score)
                .overlay(alignment: .bottom) { toastView }
                .overlay(alignment: .bottom) { pillView }
                .zIndex(1)
            PicksStreakRow(picks: vm.run.picks, total: vm.run.stagePicksAtStart,
                           streak: vm.run.streak, smult: vm.smult)
                .coachTarget(.meta)
            BlessingChips(blessings: vm.run.blessings)
            cards
            ItemBar(run: vm.run, enabled: vm.canInteract) { vm.useItem($0) }
                .coachTarget(.items)
            BankButton(run: vm.run, enabled: vm.canInteract) { vm.bank() }
                .coachTarget(.bank)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .foregroundStyle(Theme.ink)
        .accessibilityHidden(covered)
        .keyframeAnimator(initialValue: CGSize.zero, trigger: vm.shakeCount) { content, v in
            content.offset(v)
        } keyframes: { _ in
            KeyframeTrack(\.width) {
                LinearKeyframe(0, duration: 0.01)
                LinearKeyframe(-7, duration: 0.08)
                LinearKeyframe(6, duration: 0.08)
                LinearKeyframe(-4, duration: 0.08)
                LinearKeyframe(3, duration: 0.08)
                LinearKeyframe(0, duration: 0.08)
            }
            KeyframeTrack(\.height) {
                LinearKeyframe(0, duration: 0.01)
                LinearKeyframe(3, duration: 0.08)
                LinearKeyframe(-4, duration: 0.08)
                LinearKeyframe(2, duration: 0.08)
                LinearKeyframe(-1, duration: 0.08)
                LinearKeyframe(0, duration: 0.08)
            }
        }
    }

    private var cards: some View {
        HStack(spacing: 10) {
            ForEach(Array(vm.faces.enumerated()), id: \.offset) { i, face in
                CardView(
                    face: face,
                    isArmed: vm.pickedIndex == i && vm.reveal == nil,
                    isDimmed: vm.pickedIndex != nil && vm.pickedIndex != i,
                    reveal: vm.pickedIndex == i ? vm.reveal : nil,
                    action: { vm.pick(i) }
                )
                .accessibilityIdentifier("card.\(i)")
                .id("\(vm.dealID)-\(i)")
                .transition(reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .offset(y: 26).combined(with: .scale(scale: 0.94)).combined(with: .opacity),
                        removal: .identity))
            }
        }
        .frame(maxHeight: .infinity)
        .coachTarget(.cards)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.26, dampingFraction: 0.65),
                   value: vm.dealID)
    }

    // MARK: Sheets

    @ViewBuilder
    private var sheetContent: some View {
        switch vm.sheet {
        case .fail:
            FailSheet(stage: vm.run.stage,
                      missing: max(0, vm.target - vm.run.value),
                      adState: vm.adButtonState,
                      endRun: { vm.endRun() },
                      watchAd: { vm.watchAd() })
        case .shop:
            ShopSheet(vm: vm)
        case .difficulty:
            DifficultySheet(currentLevel: vm.mode == .free ? vm.run.lv : -1,
                            unlock: vm.unlock,
                            inProgress: vm.difficultyReplacesRun,
                            pick: { vm.startLevel($0) },
                            cancel: { vm.closeDifficulty() })
        case .result:
            ResultSheet(run: vm.run, unlock: vm.unlock, deepest: vm.deepest,
                        nextAttempt: vm.nextDailyAttempt, broken: vm.brokenRecords,
                        actions: .init(sameDeck: { vm.retrySameDeck() },
                                       newRun: { vm.startNewRun() },
                                       endless: { vm.startEndless() },
                                       changeLevel: { vm.openDifficulty() },
                                       playLevel: { vm.startLevel($0) },
                                       copy: { vm.copyResult() },
                                       free: { vm.switchMode(.free) }))
        case .rules:
            RulesSheet(mode: vm.mode, attempt: vm.run.attempt,
                       targets: (1...Rules.STAGES).map { GameEngine.targetOf(vm.run, stage: $0) },
                       deepest: vm.deepest, muted: vm.muted,
                       toggleMute: { vm.toggleMute() },
                       replayTour: { vm.replayOnboarding() },
                       openLevel: { vm.openDifficulty() },
                       openRecords: { vm.openDashboard() },
                       showsPrivacyOptions: ConsentManager.shared.privacyOptionsRequired,
                       openPrivacy: { ConsentManager.shared.presentPrivacyOptions() },
                       abandon: { vm.abandon() },
                       close: { vm.closeRules() })
        case .dashboard:
            DashboardSheet(stats: vm.stats, daily: vm.dailyLog, unlock: vm.unlock, today: vm.today,
                           hasRecords: vm.hasRecords, broken: vm.run.brokenRecords,
                           close: { vm.closeDashboard() })
        case nil:
            EmptyView()
        }
    }
}

/// Debug-only stand-in for the rewarded ad (UI tests with -noAds / -seed; the prototype's 2.5s mock screen).
private struct AdMockView: View {
    let duration: Double
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            Theme.deepNight.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("廣告播放中…（模擬）")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkMuted)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule().fill(Theme.gold).frame(width: geo.size.width * progress)
                    }
                }
                .frame(width: 200, height: 6)
            }
        }
        .onAppear { withAnimation(.linear(duration: duration)) { progress = 1 } }
        .accessibilityElement(children: .combine)
    }
}
