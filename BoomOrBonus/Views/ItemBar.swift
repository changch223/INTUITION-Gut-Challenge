//
//  ItemBar.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.7. Shield is passive (dashed, tap shows an explanation).
//

import SwiftUI

struct ItemBar: View {
    let run: RunState
    let enabled: Bool
    let use: (ItemID) -> Void

    var body: some View {
        HStack(spacing: 6) {
            shieldCell
            activeCell(.peek, hint: "看會不會爆", armed: run.peekArmed, count: run.inventory.peek)
            activeCell(.roll, hint: "換一組牌", armed: false, count: run.inventory.roll)
            activeCell(.dbl, hint: "得分 ×2", armed: run.doubleArmed, count: run.inventory.dbl)
        }
    }

    private var shieldCell: some View {
        Button { use(.shield) } label: {
            cell(count: "\(run.shield)", name: "保命符", hint: "自動擋爆")
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .opacity(run.shield > 0 ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("保命符，\(run.shield) 張，自動擋下爆炸")
        .accessibilityIdentifier("item.shield")
    }

    private func activeCell(_ item: ItemID, hint: LocalizedStringKey, armed: Bool, count: Int) -> some View {
        Button { use(item) } label: {
            cell(count: armed ? "✓" : "\(count)", name: LocalizedStringKey(item.name), hint: hint, armed: armed)
                .opacity(!armed && count <= 0 ? 0.38 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || (!armed && count <= 0))
        .accessibilityIdentifier("item.\(item.rawValue)")
        .accessibilityLabel(armed
            ? "\(item.name)，已啟用"
            : "\(item.name)，\(count) 個，\(Self.hintText(item))")
    }

    private static func hintText(_ item: ItemID) -> String {
        switch item {
        case .peek: return String(localized: "看會不會爆")
        case .roll: return String(localized: "換一組牌")
        case .dbl: return String(localized: "下一張牌得分加倍")
        case .shield: return String(localized: "自動擋爆")
        }
    }

    private func cell(count: String, name: LocalizedStringKey, hint: LocalizedStringKey, armed: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(count).font(Theme.number(17))
            Text(name).font(.system(size: 12))
            Text(hint).font(.system(size: 10.5, weight: .medium)).opacity(0.72)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(armed ? Theme.goldText : Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.top, 8).padding(.bottom, 7).padding(.horizontal, 2)
        .background(armed ? Theme.gold : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
