//
//  ScorePanel.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.3: big score, goal line, progress bar, bar labels.
//

import SwiftUI

struct ScorePanel: View {
    let value: Int
    let target: Int
    let stretch: Int
    let isFirstPick: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var reachedTarget: Bool { value >= target }
    private var reachedStretch: Bool { value >= stretch }

    var body: some View {
        VStack(spacing: 0) {
            let text = Fmt.int(value)
            Text(text)
                .font(Theme.number(Self.fontSize(forDigits: text.count)))
                .tracking(-1.5)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: Double(value)))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.42), value: value)
                .frame(height: 86)
                .accessibilityLabel("分數 \(value)")
                .accessibilityIdentifier("score")

            goal
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.inkMuted)
                .frame(minHeight: 22)
                .padding(.top, 2).padding(.bottom, 9)

            bar
            barLabels
        }
        .padding(.top, 2)
    }

    /// 02 §2.3: 3 digits or fewer 84pt, 5 -> 64, 7 -> 50, 9 -> 40 (then 32 / 26 like the prototype).
    static func fontSize(forDigits n: Int) -> CGFloat {
        switch n {
        case ...3: return 84
        case ...5: return 64
        case ...7: return 50
        case ...9: return 40
        case ...11: return 32
        default: return 26
        }
    }

    private var goal: Text {
        let head = Text("目標 ") + Text(Fmt.int(target)).font(Theme.number(16)).foregroundColor(Theme.ink) + Text("　")
        if reachedStretch {
            return head + Text("超標達成，過關多拿 $3")
        } else if reachedTarget {
            return head + (isFirstPick
                ? Text("帶來的分數已經夠了，選 1 手就能過關")
                : Text("已達標，超標線是 \(Fmt.int(stretch))"))
        } else {
            return head + Text("還差 \(Fmt.int(target - value))")
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fraction = max(0, min(1, Double(value) / Double(max(1, stretch))))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.16))
                RoundedRectangle(cornerRadius: 5)
                    .fill(reachedStretch ? Theme.gold : Theme.mint)
                    .frame(width: w * fraction)
                    .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.45), value: fraction)
                // The target line sits at target / stretch = 1 / 1.5.
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.ink)
                    .frame(width: 2, height: 18)
                    .offset(x: w * (1 / Rules.STR) - 1)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    private var barLabels: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                (Text("過關 ") + Text(Fmt.int(target)).bold().foregroundColor(Theme.ink))
                    .lineLimit(1)
                    .frame(width: max(0, w / Rules.STR - 6), alignment: .trailing)
                (Text("超標 ") + Text(Fmt.int(stretch)).bold() + Text(" +$3"))
                    .lineLimit(1)
                    .foregroundStyle(reachedStretch ? Theme.gold : Theme.inkMuted)
                    .frame(width: w, alignment: .trailing)
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.inkMuted)
        .frame(height: 16)
        .padding(.top, 6)
        .accessibilityHidden(true)
    }
}
