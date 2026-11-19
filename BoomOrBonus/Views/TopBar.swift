//
//  TopBar.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.1. Free play: the difficulty chip opens the difficulty sheet (Phase 3).
//  Daily challenge (Phase 4): the chip reads "M/D 第 N 次 ▾" and also opens the difficulty sheet;
//  picking a level there switches to free play and leaves the daily run alone (prototype #cDay).
//  ? opens the rules panel (02 §2.1; id kept as topbar.menu); ★ opens 我的紀錄 (Phase 6; topbar.records).
//

import SwiftUI

struct TopBar: View {
    let run: RunState
    var levelEnabled = true
    var openLevel: () -> Void = {}
    var menuEnabled = true
    var openMenu: () -> Void = {}
    var recordsEnabled = true
    var openRecords: () -> Void = {}

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

            if run.mode == .daily {
                dayChip
            } else {
                levelChip
            }

            Spacer(minLength: 0)

            Button(action: openRecords) {
                glyph("★")
            }
            .buttonStyle(.plain)
            .disabled(!recordsEnabled)
            .accessibilityLabel("我的紀錄")
            .accessibilityIdentifier("topbar.records")
            Button(action: openMenu) {
                glyph("?")
            }
            .buttonStyle(.plain)
            .disabled(!menuEnabled)
            .accessibilityLabel("選單")
            .accessibilityIdentifier("topbar.menu")
        }
        .foregroundStyle(Theme.ink)
        .frame(height: 34)
    }

    private var levelChip: some View {
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
    }

    /// "11/16 第 2 次": today's date and which attempt this run is.
    private var dayChip: some View {
        let md = DayKey.monthDay(run.day)
        return Button(action: openLevel) {
            Text("\(md) 第 \(run.attempt) 次 ▾")
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!levelEnabled)
        .accessibilityLabel("今日挑戰，\(md)，第 \(run.attempt) 次")
        .accessibilityHint("選擇難度")
        .accessibilityIdentifier("topbar.day")
    }

    private func glyph(_ g: String) -> some View {
        Text(g)
            .font(Theme.number(15))
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.14), in: Circle())
            .contentShape(Circle())
    }
}
