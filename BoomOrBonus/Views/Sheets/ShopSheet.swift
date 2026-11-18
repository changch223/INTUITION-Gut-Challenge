//
//  ShopSheet.swift
//  BoomOrBonus
//
//  02-screens-ux.md §4.1: coin breakdown, next-stage preview, 3 blessing slots, items,
//  「換一批」 and 「前往第 N 關」. The buttons stay pinned under the scrolling list and the
//  (mocked) banner ad sits at the very bottom (02 §12).
//

import SwiftUI

struct ShopSheet: View {
    let vm: GameViewModel

    private var run: RunState { vm.run }
    private var reward: Int { run.lastRewardParts.reduce(0) { $0 + $1.amount } }

    private let compact = SheetScaffold<EmptyView, EmptyView>.isShortScreen

    var body: some View {
        SheetScaffold {
            list
        } footer: {
            VStack(spacing: 10) {
                footer
                MockBannerView()
            }
        }
    }

    // MARK: List

    private var list: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            SheetTitle(small: clearedText, big: Text("商店　$\(run.coins)"))
                .accessibilityIdentifier("shop.title")
            breakdown
            preview
            SheetLabel(text: Text("祝福（已有 \(run.blessings.count) / \(Rules.MAX_BLESSINGS)）"))
            if run.shopOffer.isEmpty {
                SheetBody(text: Text("祝福已經帶滿，也沒有可以重複買的。"))
            } else {
                ForEach(Array(run.shopOffer.enumerated()), id: \.offset) { i, id in
                    slot(i, id)
                }
            }
            SheetLabel(text: Text("道具"))
            HStack(spacing: 6) {
                ForEach(ItemID.allCases, id: \.self) { item in itemCell(item) }
            }
        }
    }

    private var clearedText: Text {
        run.endless && run.stage > Rules.STAGES
            ? Text("無盡 第 \(run.stage) 關過關，拿到 $\(reward)")
            : Text("第 \(run.stage) 關過關，拿到 $\(reward)")
    }

    private var breakdown: some View {
        VStack(spacing: compact ? 3 : 5) {
            ForEach(Array(run.lastRewardParts.enumerated()), id: \.offset) { _, p in
                HStack {
                    Text(verbatim: vm.shopLabel(for: p))
                    Spacer(minLength: 8)
                    Text("$\(p.amount)").font(Theme.number(13))
                }
            }
            // The title already says the total; on short screens the extra row is dropped to save height.
            if !compact {
                Divider()
                HStack {
                    Text("這關合計").fontWeight(.bold)
                    Spacer()
                    Text("$\(reward)").font(Theme.number(13)).fontWeight(.bold)
                }
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.sheetText)
        .padding(.horizontal, 12).padding(.vertical, compact ? 7 : 9)
        .background(Color(hex: 0xF0F1FA), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shop.breakdown")
    }

    /// Next stage: target plus the boss (red tint) or the stage rule.
    private var preview: some View {
        let boss = vm.nextBoss
        let mod = vm.nextMod
        return VStack(alignment: .leading, spacing: 3) {
            (Text("下一關目標 ") + Text(Fmt.int(vm.nextTarget)).bold())
            if let boss {
                Text("魔王「\(boss.name)」：\(boss.desc)").foregroundStyle(Theme.red).fontWeight(.medium)
            } else if let mod {
                Text("規則「\(mod.name)」：\(mod.desc)").foregroundStyle(Theme.sheetBody)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.sheetText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(boss != nil ? Theme.red.opacity(0.12) : Color(hex: 0xF0F1FA), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shop.preview")
    }

    // MARK: Blessing slots

    @ViewBuilder
    private func slot(_ i: Int, _ id: BlessingID?) -> some View {
        if let id {
            let owned = run.level(id)
            let price = vm.price(id.basePrice)
            let ok = vm.canBuy(id)
            Button { vm.buyBlessing(id) } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(verbatim: owned > 0 ? "\(id.name)（已有 \(owned)）" : id.name)
                                .font(.system(size: 14.5, weight: .bold))
                            Text(verbatim: id.tag)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Theme.sheetMuted)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.white.opacity(0.7), in: Capsule())
                        }
                        Text(verbatim: id.desc)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sheetBody)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Text("$\(price)").font(Theme.number(15))
                }
                .foregroundStyle(Theme.sheetText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.sheetButton, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!ok)
            .opacity(ok ? 1 : 0.45)
            .accessibilityLabel(slotLabel(id, price: price, ok: ok))
            .accessibilityIdentifier("shop.blessing.\(i)")
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text("已購買").font(.system(size: 14.5, weight: .bold))
                Text("這個位置賣完了").font(.system(size: 12))
            }
            .foregroundStyle(Theme.sheetMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Theme.sheetButton.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("已購買，這個位置賣完了")
            .accessibilityIdentifier("shop.blessing.\(i)")
        }
    }

    private func slotLabel(_ id: BlessingID, price: Int, ok: Bool) -> String {
        var s = id.name
        if run.has(id) { s += String(localized: "，已有 \(run.level(id)) 層") }
        s += "，" + id.desc + "，" + String(localized: "$\(price)")
        if !ok {
            if vm.run.coins < price { s += String(localized: "，金幣不夠") }
            else if !run.has(id) { s += String(localized: "，祝福已滿") }
        }
        return s
    }

    // MARK: Items

    private func itemCell(_ item: ItemID) -> some View {
        let price = vm.price(item.basePrice)
        let ok = vm.canBuy(item)
        let have = item == .shield ? run.shield : (item == .peek ? run.inventory.peek : item == .roll ? run.inventory.roll : run.inventory.dbl)
        return Button { vm.buyItem(item) } label: {
            VStack(spacing: 2) {
                Text(verbatim: item.name).font(.system(size: 13, weight: .bold))
                Text("$\(price)").font(Theme.number(14))
                Text("有 \(have)").font(.system(size: 11)).foregroundStyle(Theme.sheetMuted)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Theme.sheetText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Theme.sheetButton, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!ok)
        .opacity(ok ? 1 : 0.45)
        .accessibilityLabel("\(item.name)，$\(price)，有 \(have) 個" + (ok ? "" : String(localized: "，金幣不夠")))
        .accessibilityIdentifier("shop.item.\(item.rawValue)")
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button { vm.rerollShop() } label: { Text("換一批 $\(GameViewModel.rerollCost)") }
                .buttonStyle(SheetButtonStyle())
                .frame(maxWidth: 130)
                .disabled(!vm.canReroll)
                .opacity(vm.canReroll ? 1 : 0.45)
                .accessibilityIdentifier("shop.reroll")
            Button { vm.nextStage() } label: { Text("前往第 \(vm.nextStageNumber) 關") }
                .buttonStyle(SheetButtonStyle(primary: true))
                .accessibilityIdentifier("shop.next")
        }
    }
}
