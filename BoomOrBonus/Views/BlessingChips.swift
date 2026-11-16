//
//  BlessingChips.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.5.
//

import SwiftUI

struct BlessingChips: View {
    let blessings: [BlessingID: Int]

    var body: some View {
        HStack(spacing: 5) {
            if blessings.isEmpty {
                Text("還沒有祝福，過關後可以在商店買")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.vertical, 5)
            } else {
                // Declaration order keeps the row stable between renders.
                ForEach(BlessingID.allCases.filter { blessings[$0] != nil }, id: \.self) { b in
                    let n = blessings[b] ?? 0
                    Text(n > 1 ? "\(b.name) ×\(n)" : b.name)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(hex: 0xE2E5FF))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 7).padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.35), lineWidth: 1))
                        .accessibilityLabel(n > 1 ? "祝福 \(b.name) \(n) 層" : "祝福 \(b.name)")
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 22, alignment: .topLeading)
    }
}
