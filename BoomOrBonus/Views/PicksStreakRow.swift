//
//  PicksStreakRow.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.4: picks left with dots, streak capsule.
//

import SwiftUI

struct PicksStreakRow: View {
    let picks: Int
    let total: Int          // this stage's picks at start
    let streak: Int
    let smult: Double

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Text("剩 \(picks) 手")
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.trailing, 4)
                ForEach(0..<max(total, picks), id: \.self) { i in
                    Circle()
                        .fill(i < picks ? Theme.ink : Color.white.opacity(0.18))
                        .frame(width: 11, height: 11)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("剩 \(picks) 手，共 \(max(total, picks)) 手")
            .accessibilityIdentifier("picks")

            Spacer(minLength: 8)

            Group {
                if streak > 0 {
                    Text("連中 \(streak) · 得分 ×\(Fmt.num(smult))")
                        .foregroundStyle(Theme.goldText)
                } else {
                    Text("連中 0")
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .font(Theme.number(13))
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(streak > 0 ? Theme.gold : Color.white.opacity(0.12), in: Capsule())
            .accessibilityLabel(streak > 0 ? "連中 \(streak)，得分乘 \(Fmt.num(smult))" : "連中 0")
        }
        .frame(height: 24)
    }
}
