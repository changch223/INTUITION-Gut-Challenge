//
//  BankButton.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.8: two lines, disabled until the target is met.
//

import SwiftUI

struct BankButton: View {
    let run: RunState
    let enabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    private var target: Int { GameEngine.target(run) }
    private var stretch: Int { GameEngine.stretch(run) }
    private var ready: Bool { GameEngine.canClear(run) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                title.font(.system(size: ready ? 16 : 14, weight: ready ? .bold : .medium))
                subtitle.font(.system(size: 11.5, weight: .medium)).opacity(0.78)
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .foregroundStyle(ready ? Theme.goldText : Theme.inkFaint)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .padding(.horizontal, 10)
            .background(ready ? Theme.gold : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if ready {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.gold.opacity(0.3), lineWidth: 5)
                        .padding(-2.5)
                        .opacity(glow ? 1 : 0)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!ready || !enabled)
        .onChange(of: ready) { _, isReady in updateGlow(isReady) }
        .onAppear { updateGlow(ready) }
        .accessibilityLabel(a11y)
        .accessibilityIdentifier("bank")
    }

    private func updateGlow(_ on: Bool) {
        if on && !reduceMotion {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true }
        } else {
            withAnimation(.linear(duration: 0)) { glow = on }
        }
    }

    private var title: Text {
        if ready { return Text("過關，拿 $\(GameEngine.reward(run))") }
        if run.value >= target { return Text("先選 1 手才能過關") }
        return Text("達到 \(Fmt.int(target)) 分才能過關")
    }

    private var subtitle: Text {
        if ready {
            let parts = GameEngine.rewardParts(run).map { "\(partLabel($0)) $\($0.amount)" }.joined(separator: " + ")
            let tail = run.value < stretch ? String(localized: "　·　") + String(localized: "到 \(Fmt.int(stretch)) 再 +$3") : ""
            return Text(verbatim: parts + tail)
        }
        if run.value >= target { return Text("每關至少要選 1 手") }
        let base = GameEngine.rewardParts(run)[0].amount
        let perHand = GameEngine.modOf(run) == .rich ? 2 : 1
        return Text("過關 $\(base) ＋ 剩下每手 $\(perHand) ＋ 超標再 $3")
    }

    private func partLabel(_ p: RewardPart) -> String {
        switch p.kind {
        case .base: return String(localized: "基本")
        case .picksLeft: return String(localized: "剩 \(run.picks) 手")
        case .stretch: return String(localized: "超標")
        case .interest: return String(localized: "利息")
        }
    }

    private var a11y: String {
        if ready { return String(localized: "過關，拿 \(GameEngine.reward(run)) 金幣") }
        if run.value >= target { return String(localized: "先選 1 手才能過關") }
        return String(localized: "達到 \(target) 分才能過關，還差 \(target - run.value) 分")
    }
}
