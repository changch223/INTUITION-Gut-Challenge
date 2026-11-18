//
//  TopBar.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.1. The difficulty chip opens the difficulty sheet (Phase 3);
//  ★ (records, Phase 6) and ? (rules, Phase 5) are shown but inert.
//  Daily mode (Phase 4) will change the chip to "M/D 第 N 次".
//

import SwiftUI

struct TopBar: View {
    let run: RunState
    var levelEnabled = true
    var openLevel: () -> Void = {}

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

            Button(action: openLevel) {
                Text("練習 · \(Rules.difficulties[run.lv].name) ▾")
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!levelEnabled)
            .accessibilityLabel("練習，難度「\(Rules.difficulties[run.lv].name)」，選擇難度")
            .accessibilityIdentifier("topbar.level")

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
