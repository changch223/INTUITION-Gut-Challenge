//
//  RuleBanner.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.2. Boss stage: red. Other stages: translucent, name in gold.
//

import SwiftUI

struct RuleBanner: View {
    let boss: BossID?
    let mod: ModID?

    var body: some View {
        if let boss {
            banner(
                title: Text("魔王 \(boss.name)").fontWeight(.bold),
                desc: boss.desc,
                background: Theme.red,
                foreground: .white
            )
        } else if let mod {
            banner(
                title: Text("本關規則 \(mod.name)").fontWeight(.bold).foregroundColor(Theme.gold),
                desc: mod.desc,
                background: Color.white.opacity(0.16),
                foreground: Theme.ink
            )
        }
    }

    private func banner(title: Text, desc: String, background: Color, foreground: Color) -> some View {
        (title + Text("  ") + Text(desc))
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(foreground)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
    }
}
