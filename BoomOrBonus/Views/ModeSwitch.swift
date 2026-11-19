//
//  ModeSwitch.swift
//  BoomOrBonus
//
//  02-screens-ux.md §11: two segments above the game area, 今日挑戰 / 自由練習. Each mode keeps its own
//  run, so switching just picks the other one up. It is drawn above the sheets' scrim and only dimmed
//  (and ignored by the view model) while a pick / clear animation runs or the mock ad plays.
//

import SwiftUI

struct ModeSwitch: View {
    /// 4 + 34 + 4 padding: the game layout reserves this much room under the switch.
    static let height: CGFloat = 42

    let mode: Mode
    var enabled = true
    var select: (Mode) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 4) {
            segment(.daily, title: "今日挑戰", id: "mode.daily")
            segment(.free, title: "自由練習", id: "mode.free")
        }
        .padding(4)
        .background(Color.white.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        .opacity(enabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.15), value: enabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("模式")
    }

    private func segment(_ m: Mode, title: LocalizedStringKey, id: String) -> some View {
        let selected = mode == m
        return Button { select(m) } label: {
            Text(title)
                .font(.system(size: 14, weight: selected ? .bold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(selected ? Theme.night : Theme.inkMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(selected ? Theme.ink : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
