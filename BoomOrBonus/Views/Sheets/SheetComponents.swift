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

/// Stand-in for the banner ad (02 §12: banners live only in the shop and on the result sheet).
/// Phase 7 swaps this for the real `BannerAdView`.
struct MockBannerView: View {
    var body: some View {
        Text("廣告（模擬）")
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Theme.sheetMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Theme.sheetButton.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
            .accessibilityIdentifier("bannerMock")
    }
}

/// Small grey section label ("祝福（已有 1 / 5）").
struct SheetLabel: View {
    let text: Text
    var body: some View {
        text.font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(Theme.sheetMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }
}

private struct ListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct VisibleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Cream bottom panel with a scrolling list and a footer that is always on screen (shop, difficulty).
/// One ScrollView sized to its content (never swapped for another variant), so the scroll position
/// survives content changes such as buying something. A bottom fade hints that there is more below.
struct SheetScaffold<List: View, Footer: View>: View {
    @ViewBuilder let list: List
    @ViewBuilder let footer: Footer

    @State private var listHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0

    /// iPhone SE class screens: callers use tighter spacing.
    static var isShortScreen: Bool { UIScreen.main.bounds.height < 740 }

    private var scrollable: Bool { listHeight > visibleHeight + 1 }

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                list
                    .padding(.bottom, scrollable ? 18 : 0)
                    .background(GeometryReader { Color.clear.preference(key: ListHeightKey.self, value: $0.size.height) })
            }
            .scrollBounceBehavior(.basedOnSize)
            .onPreferenceChange(ListHeightKey.self) { listHeight = $0 }
            .frame(maxHeight: listHeight > 0 ? listHeight : .infinity)
            .background(GeometryReader { Color.clear.preference(key: VisibleHeightKey.self, value: $0.size.height) })
            .onPreferenceChange(VisibleHeightKey.self) { visibleHeight = $0 }
            .overlay(alignment: .bottom) {
                if scrollable {
                    LinearGradient(colors: [Theme.sheetBg.opacity(0), Theme.sheetBg], startPoint: .top, endPoint: .bottom)
                        .frame(height: 26)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            footer
        }
        .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 12)
        .background {
            Theme.sheetBg
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
