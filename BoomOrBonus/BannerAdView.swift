//
//  BannerAdView.swift
//  BoomOrBonus
//
//  Adaptive banner for the shop and the result sheet (02-screens-ux.md §12).
//

import SwiftUI
import GoogleMobileAds

/// The banner strip of the shop and the result sheet (02 §12). It is hosted by `GameScreen` below the sheet, outside
/// the sheet's own layout (no `ViewThatFits`, so a layout flip never re-creates the banner and re-requests it),
/// pinned above the bottom safe area. It sits well clear of every button (accidental-click policy): the sheet's
/// bottom padding plus 8 pt and a hairline with a small 「廣告」 label come first.
/// The strip reserves its height while the ad loads and collapses completely when the load fails.
struct AdBannerStrip: View {
    /// 8 + 13 + 2 + 50, before the strip is measured.
    static let estimatedHeight: CGFloat = 73
    private static let placeholderHeight: CGFloat = 50
    @State private var height: CGFloat = AdBannerStrip.placeholderHeight
    /// The strip's total height as it is drawn now (0 once the load failed): GameScreen takes it off the sheet's space.
    var onTotalHeight: (CGFloat) -> Void = { _ in }

    private var total: CGFloat { height > 0 ? 8 + 13 + 2 + height : 0 }

    var body: some View {
        if AdConfig.suppressed || !ConsentManager.shared.canRequestAds {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                if height > 0 {
                    // Hairline with the small 「廣告」 label in it: one 13 pt row, so the strip still fits under the
                    // shop's buttons on an iPhone SE.
                    HStack(spacing: 8) {
                        Rectangle().fill(Theme.sheetMuted.opacity(0.25)).frame(height: 0.5)
                        Text("廣告")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.sheetMuted)
                            .fixedSize()
                        Rectangle().fill(Theme.sheetMuted.opacity(0.25)).frame(height: 0.5)
                    }
                    .frame(height: 13)
                    .padding(.bottom, 2)
                }
                GeometryReader { geo in
                    BannerAdView(adUnitID: AdConfig.banner, width: geo.size.width) { height = $0 }
                }
                .frame(height: height)
                .clipped()
            }
            .padding(.horizontal, 18)
            .padding(.top, height > 0 ? 8 : 0)
            .frame(maxWidth: .infinity)
            .background(Theme.sheetBg.ignoresSafeArea(edges: .bottom))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("banner.strip")
            .onChange(of: height, initial: true) { onTotalHeight(total) }
            .onDisappear { onTotalHeight(AdBannerStrip.estimatedHeight) }
        }
    }
}

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat
    /// New strip height: the ad's height once loaded, 0 when the load failed.
    let onHeight: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onHeight: onHeight) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.topViewController
        banner.delegate = context.coordinator
        context.coordinator.requestedWidth = width
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        context.coordinator.onHeight = onHeight
        // A rotation or a different sheet width asks for a new adaptive size.
        if abs(context.coordinator.requestedWidth - width) > 1, width > 0 {
            context.coordinator.requestedWidth = width
            banner.adSize = adSize
            banner.load(Request())
        }
    }

    private var adSize: AdSize { currentOrientationAnchoredAdaptiveBanner(width: max(width, 320)) }

    final class Coordinator: NSObject, BannerViewDelegate {
        var onHeight: (CGFloat) -> Void
        var requestedWidth: CGFloat = 0
        init(onHeight: @escaping (CGFloat) -> Void) { self.onHeight = onHeight }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            let h = bannerView.adSize.size.height
            DispatchQueue.main.async { self.onHeight(h) }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            DispatchQueue.main.async { self.onHeight(0) }
        }
    }
}
