//
//  CoachMarkOverlay.swift
//  BoomOrBonus
//
//  02-screens-ux.md §7: the six-step onboarding. A dark scrim with a cut-out around the step's target, a gold
//  ring and a callout card (above the target when the target is in the lower half, below otherwise).
//  Targets are measured with anchor preferences (`coachTarget`), never hard-coded, so the cut-out follows
//  the layout on every screen size. The scrim swallows every tap; only the callout's buttons act.
//

import SwiftUI

// MARK: - Steps

/// What a step circles. Each case is tagged on the real view in GameScreen with `coachTarget(_:)`.
enum CoachTarget: Hashable {
    case score, cards, meta, items, bank

    /// VoiceOver name of the circled area.
    var label: String {
        switch self {
        case .score: return String(localized: "分數區")
        case .cards: return String(localized: "兩張牌")
        case .meta: return String(localized: "手數與連中")
        case .items: return String(localized: "道具列")
        case .bank: return String(localized: "過關按鈕")
        }
    }
}

struct CoachStep: Equatable {
    let target: CoachTarget
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    let a11yTitle: String

    /// Copy and order from 02 §7 (prototype COACH).
    static let all: [CoachStep] = [
        CoachStep(target: .score, title: "目標分數",
                  text: "每關要在 7 手內把分數打到目標，下一關從 0 開始。進度條上的白線是過關線，最右邊是超標線。上方的橫條是這關的特殊規則，每關都不一樣。",
                  a11yTitle: String(localized: "目標分數")),
        CoachStep(target: .cards, title: "二選一，看危險度",
                  text: "底下的引信格數越多越容易爆，分數也越大。深色牌是倍數牌，乘在這關的分數上，分數越高越值錢。爆了只會扣 1 手，不會直接結束。",
                  a11yTitle: String(localized: "二選一，看危險度")),
        CoachStep(target: .meta, title: "手數與連中",
                  text: "白點是剩下的手數。連續選中會累積連中，每次得分多 25%，最多兩倍。連中會帶到下一關，但爆一次就歸零。",
                  a11yTitle: String(localized: "手數與連中")),
        CoachStep(target: .items, title: "保命符與道具",
                  text: "保命符不用按。選到會爆的牌時它自動擋下：這手不算、不扣手數，連中也不會斷。透視、重抽、雙倍要自己按，用一次就沒了。",
                  a11yTitle: String(localized: "保命符與道具")),
        CoachStep(target: .bank, title: "過關拿金幣",
                  text: "達標後按這裡過關。金幣＝基本 $3＋剩下每一手 $1，打到超標線（目標的 1.5 倍）再多 $3。金幣在關卡之間的商店買祝福和道具。",
                  a11yTitle: String(localized: "過關拿金幣")),
        CoachStep(target: .score, title: "要不要拚超標？",
                  text: "達標後可以繼續打。到超標線多拿 $3、戰績格變金色，分數也算進最後的總分。代價是每多用一手少 $1，也多一次爆炸的風險。破關後還有無盡關卡和更高的難度。",
                  a11yTitle: String(localized: "要不要拚超標？")),
    ]
}

// MARK: - Target measuring

struct CoachTargetKey: PreferenceKey {
    static var defaultValue: [CoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachTarget: Anchor<CGRect>], nextValue: () -> [CoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Reports this view's bounds so the coach mark can circle it.
    func coachTarget(_ target: CoachTarget) -> some View {
        anchorPreference(key: CoachTargetKey.self, value: .bounds) { [target: $0] }
    }
}

// MARK: - Overlay

struct CoachMarkOverlay: View {
    let step: Int
    /// Target frames in this view's own space (resolved by the caller from the anchors).
    let frames: [CoachTarget: CGRect]
    let size: CGSize
    let next: () -> Void
    let skip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var calloutFocused: Bool

    /// Space between the target and the ring (prototype: 5pt).
    static let ringInset: CGFloat = 5

    private var data: CoachStep { CoachStep.all[min(max(0, step), CoachStep.all.count - 1)] }
    private var isLast: Bool { step >= CoachStep.all.count - 1 }
    private var hole: CGRect? { frames[data.target]?.insetBy(dx: -Self.ringInset, dy: -Self.ringInset) }
    private var move: Animation? { reduceMotion ? nil : .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.32) }

    var body: some View {
        ZStack {
            // Swallows every tap, the hole included: the game underneath must not react.
            CutoutShape(hole: hole, radius: 18)
                .fill(Theme.coachScrim, style: FillStyle(eoFill: true))
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)

            if let hole {
                // Outside the cut-out, like the prototype's outline (2pt wide, 2pt away from the hole).
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Theme.gold, lineWidth: 2)
                    .frame(width: hole.width + 8, height: hole.height + 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "標示的區塊：\(data.target.label)"))
                    .accessibilityIdentifier("coach.highlight")
                    .allowsHitTesting(false)
                    .position(x: hole.midX, y: hole.midY)

                callout(around: hole)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(move, value: hole)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, skip)
        .onAppear { focusCallout() }
        .onChange(of: step) { _, _ in focusCallout() }
    }

    /// VoiceOver lands on the callout text, and again on every step.
    private func focusCallout() {
        calloutFocused = false
        DispatchQueue.main.async { calloutFocused = true }
    }

    @ViewBuilder
    private func callout(around hole: CGRect) -> some View {
        let below = hole.midY <= size.height / 2
        card
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: below ? .top : .bottom)
            .padding(below ? .top : .bottom, below ? hole.maxY + 13 : size.height - hole.minY + 13)
            .frame(width: size.width, height: size.height)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text("新手導覽 \(step + 1) / \(CoachStep.all.count)")
                    .font(Theme.number(12))
                    .tracking(0.7)
                    .foregroundStyle(Theme.sheetMuted)
                Text(data.title)
                    .font(Theme.number(19))
                    .foregroundStyle(Theme.sheetText)
                Text(data.text)
                    .font(.system(size: 13.5))
                    .lineSpacing(3.5)
                    .foregroundStyle(Theme.sheetBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityFocused($calloutFocused)
            .accessibilityIdentifier("coach.text")

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                if !isLast {
                    Button("跳過", action: skip)
                        .buttonStyle(CoachButtonStyle())
                        .accessibilityIdentifier("coach.skip")
                }
                Button(isLast ? "開始玩" : "下一步", action: next)
                    .buttonStyle(CoachButtonStyle(primary: true))
                    .accessibilityIdentifier("coach.next")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.sheetBg, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coach.callout")
    }
}

private struct CoachButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(primary ? Color.white : Theme.sheetText)
            .padding(.horizontal, 16)
            .frame(minWidth: 64)
            .frame(height: 40)
            .background(primary ? Theme.sheetPrimary : Theme.sheetButton, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// The full rect minus a rounded hole (even-odd fill). The hole animates from one target to the next.
private struct CutoutShape: Shape {
    var hole: CGRect?
    var radius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            let h = hole ?? .zero
            return .init(.init(h.origin.x, h.origin.y), .init(h.size.width, h.size.height))
        }
        set {
            hole = CGRect(x: newValue.first.first, y: newValue.first.second,
                          width: newValue.second.first, height: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path(rect)
        if let hole { p.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius)) }
        return p
    }
}
