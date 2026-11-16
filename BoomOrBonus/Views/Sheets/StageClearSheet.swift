//
//  StageClearSheet.swift
//  BoomOrBonus
//
//  Phase 3 replaces this with ShopSheet.
//  Minimal interstitial after clearStage: reward breakdown and 「下一關」.
//

import SwiftUI

// Phase 3 replaces this with ShopSheet
struct StageClearSheet: View {
    let stage: Int
    let parts: [(label: String, amount: Int)]
    let total: Int
    let next: () -> Void

    var body: some View {
        SheetContainer {
            SheetTitle(
                small: Text("第 \(stage) 關過關"),
                big: Text("拿到 $\(total)")
            )
            VStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, p in
                    HStack {
                        Text(verbatim: p.label)
                        Spacer()
                        Text("$\(p.amount)").font(Theme.number(13))
                    }
                }
                Divider()
                HStack {
                    Text("這關合計").fontWeight(.bold)
                    Spacer()
                    Text("$\(total)").font(Theme.number(13)).fontWeight(.bold)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.sheetText)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color(hex: 0xF0F1FA), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)

            Button("下一關", action: next)
                .buttonStyle(SheetButtonStyle(primary: true))
                .accessibilityIdentifier("stageclear.next")
                .padding(.top, 4)
        }
    }
}
