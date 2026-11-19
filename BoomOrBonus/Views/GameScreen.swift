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

    init() {
        _vm = State(initialValue: GameViewModel.live)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            game
                .allowsHitTesting(vm.sheet == nil && !vm.adPlaying)

            if vm.sheet != nil {
                Theme.deepNight.opacity(0.62)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    Spacer(minLength: 58)          // room for the mode switch above the scrim
                    sheetContent
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                .accessibilityAddTraits(.isModal)
            }

            // 02 §11: the mode switch lives outside the sheets (prototype tabs), so it stays usable above the scrim.
            // It is only blocked while a pick or clear animation runs, or the mock ad plays.
            VStack(spacing: 0) {
                ModeSwitch(mode: vm.mode, enabled: vm.canSwitchMode, select: { vm.switchMode($0) })
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }

            if vm.adPlaying {
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            // Midnight, or the clock / time zone changed while the app stays in the foreground.
            vm.refreshDay()
        }
        .onChange(of: scenePhase) { _, phase in
            // 03 §2.1: back from the background after midnight, yesterday's daily run is void.
            if phase == .active { vm.refreshDay() }
        }
        .animation(.easeOut(duration: 0.22), value: vm.toast)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.32), value: vm.sheet)
        .animation(.easeOut(duration: 0.25), value: vm.adPlaying)
        .onChange(of: vm.toast) { _, toast in
            if let toast { AccessibilityNotification.Announcement(toast.text).post() }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .navigationBarHidden(true)
    }

    private var covered: Bool { vm.sheet != nil || vm.adPlaying }

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

    // MARK: Game

    private var game: some View {
        VStack(spacing: 10) {
            Color.clear.frame(height: ModeSwitch.height)       // the switch itself is drawn above the scrim
            TopBar(run: vm.run, levelEnabled: vm.canInteract, openLevel: { vm.openDifficulty() },
                   menuEnabled: vm.canInteract, openMenu: { vm.openMenu() })
            RuleBanner(boss: vm.boss, mod: vm.mod)
            ScorePanel(value: vm.run.value, target: vm.target, stretch: vm.stretch, isFirstPick: vm.isFirstPick)
                .overlay(alignment: .bottom) { toastView }
            PicksStreakRow(picks: vm.run.picks, total: vm.run.stagePicksAtStart,
                           streak: vm.run.streak, smult: vm.smult)
            BlessingChips(blessings: vm.run.blessings)
            cards
            ItemBar(run: vm.run, enabled: vm.canInteract) { vm.useItem($0) }
            BankButton(run: vm.run, enabled: vm.canInteract) { vm.bank() }
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
                        nextAttempt: vm.nextDailyAttempt,
                        actions: .init(sameDeck: { vm.retrySameDeck() },
                                       newRun: { vm.startNewRun() },
                                       endless: { vm.startEndless() },
                                       changeLevel: { vm.openDifficulty() },
                                       playLevel: { vm.startLevel($0) },
                                       copy: { vm.copyResult() },
                                       free: { vm.switchMode(.free) }))
        case .menu:
            MenuSheet(mode: vm.mode, attempt: vm.run.attempt, muted: vm.muted,
                      toggleMute: { vm.toggleMute() },
                      abandon: { vm.abandon() },
                      close: { vm.closeMenu() })
        case nil:
            EmptyView()
        }
    }
}

/// Stand-in for the rewarded ad (02 §12: prototype shows a 2.5s mock screen).
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
