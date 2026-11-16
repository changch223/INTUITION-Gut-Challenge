//
//  TopBar.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.1. Day/difficulty, ★ and ? are Phase 3+ features: shown but inert.
//

import SwiftUI

struct TopBar: View {
    let run: RunState

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if run.endless {
                    Text("無盡 第 \(run.stage) 關")
                } else {
                    Text("第 \(run.stage) 關 / \(Rules.STAGES)")
                }
            }
            .font(.system(size: 12.5, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 11).padding(.vertical, 8)
            .background(Color.white.opacity(0.14), in: Capsule())

            Text("$\(run.coins)")
                .font(Theme.number(14))
                .foregroundStyle(Theme.goldText)
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background(Theme.gold, in: Capsule())
                .accessibilityLabel("金幣 \(run.coins)")

            // Placeholder until the difficulty picker exists (Phase 3).
            Text("練習 · \(Rules.difficulties[run.lv].name) ▾")
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                .opacity(0.7)

            Spacer(minLength: 0)

            iconButton("★", label: "我的紀錄")
            iconButton("?", label: "規則")
        }
        .foregroundStyle(Theme.ink)
        .frame(height: 34)
    }

    private func iconButton(_ glyph: String, label: LocalizedStringKey) -> some View {
        // Placeholder: records (Phase 6) and rules (Phase 5) do not exist yet.
        Button {} label: {
            Text(glyph)
                .font(Theme.number(15))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(true)
        .opacity(0.5)
        .accessibilityLabel(label)
    }
}
