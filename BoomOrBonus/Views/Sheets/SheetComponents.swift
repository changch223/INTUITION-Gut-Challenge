//
//  SheetComponents.swift
//  BoomOrBonus
//
//  Shared pieces of the cream bottom panels (02-screens-ux.md §1 sheetBg tokens).
//

import SwiftUI

struct SheetButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .foregroundStyle(primary ? Color.white : Theme.sheetText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(primary ? Theme.sheetPrimary : Theme.sheetButton, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// `<h4><small>…</small>…</h4>` from the prototype.
struct SheetTitle: View {
    let small: Text
    let big: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            small.font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.sheetMuted)
            big.font(Theme.number(30)).foregroundStyle(Theme.sheetText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct SheetBody: View {
    let text: Text
    var body: some View {
        text.font(.system(size: 13.5)).foregroundStyle(Theme.sheetBody)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bottom panel container: cream, rounded top, scrolls only when the content does not fit.
struct SheetContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            inner
            ScrollView { inner }
        }
        .background {
            Theme.sheetBg
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var inner: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 20)
    }
}
