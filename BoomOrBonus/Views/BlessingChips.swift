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
        WrapLayout(spacing: 5) {
            if blessings.isEmpty {
                Text("還沒有祝福，過關後可以在商店買")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.vertical, 5)
            } else {
                // Declaration order keeps the row stable between renders.
                ForEach(BlessingID.allCases.filter { blessings[$0] != nil }, id: \.self) { b in
                    let n = blessings[b] ?? 0
                    Text(n > 1 ? "\(b.displayName) ×\(n)" : b.displayName)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(hex: 0xE2E5FF))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 7).padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.35), lineWidth: 1))
                        .accessibilityLabel(n > 1 ? "祝福 \(b.displayName) \(n) 層" : "祝福 \(b.displayName)")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .topLeading)
    }
}

/// Left-aligned items that wrap onto a second line when a language's text (Russian) does not fit in one row.
struct WrapLayout: Layout {
    var spacing: CGFloat

    private func rows(_ subviews: Subviews, width: CGFloat) -> (positions: [CGPoint], size: CGSize) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        var points: [CGPoint] = []
        for v in subviews {
            let s = v.sizeThatFits(ProposedViewSize(width: width.isFinite ? width : nil, height: nil))
            if x > 0, x + s.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
            maxX = max(maxX, x - spacing)
        }
        return (points, CGSize(width: maxX, height: y + rowHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = rows(subviews, width: bounds.width)
        for (v, p) in zip(subviews, r.positions) {
            v.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }
}
