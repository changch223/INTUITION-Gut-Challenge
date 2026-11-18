//
//  DifficultySheet.swift
//  BoomOrBonus
//
//  02-screens-ux.md §9. Six levels with their cumulative rules, simulated clear rates on the right,
//  locked levels disabled. Picking a level in the middle of a run asks first, inside the sheet
//  (no system alert); 「取消」 returns to wherever the sheet was opened from.
//

import SwiftUI

struct DifficultySheet: View {
    let currentLevel: Int
    let unlock: Int
    let inProgress: Bool
    let pick: (Int) -> Void
    let cancel: () -> Void

    /// Simulated full-clear rates (01 §13, prototype SIMLV).
    private static let simRates = ["16%", "9.9%", "4.6%", "2.8%", "1.2%", "0.8%"]

    @State private var pending: Int?

    var body: some View {
        SheetScaffold {
            VStack(alignment: .leading, spacing: 12) {
                SheetTitle(small: Text("自由練習"), big: Text("選擇難度"))
                SheetBody(text: Text("破關一個難度就解鎖下一個。難度會累加：選「老手」時，「進階」的規則也一起生效。今日挑戰有自己的難度（目標 ×1.3），可以無限重打。"))

                ForEach(Array(Rules.difficulties.enumerated()), id: \.offset) { i, d in
                    option(i, name: d.name, desc: d.desc)
                }

                SheetBody(text: Text("右邊是模擬的全破率（看期望值選牌、會買祝福）。選了之後會開始新的一局。")
                    + (inProgress ? Text("目前這局會放棄。") : Text(verbatim: "")))
            }
        } footer: {
            // Pinned outside the scroll area so the confirmation can never be clipped (iPhone SE).
            if let pending {
                confirm(pending)
            } else {
                Button("取消", action: cancel)
                    .buttonStyle(SheetButtonStyle(primary: true))
                    .accessibilityIdentifier("difficulty.cancel")
            }
        }
    }

    private func option(_ i: Int, name: String, desc: String) -> some View {
        let locked = i > unlock
        let isCurrent = i == currentLevel
        let rule = i == 0 ? desc : String(localized: "前一級的規則，再加上：\(desc)")
        let lockedText = String(localized: "破關「\(Rules.difficulties[max(0, i - 1)].name)」後解鎖")
        return Button {
            if inProgress { pending = i } else { pick(i) }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "\(i + 1)　\(name)" + (isCurrent ? String(localized: "（目前）") : ""))
                        .font(.system(size: 14.5, weight: .bold))
                    Text(verbatim: locked ? lockedText : rule)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sheetBody)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(Theme.sheetMuted)
                } else {
                    Text(verbatim: Self.simRates[i]).font(Theme.number(13)).foregroundStyle(Theme.sheetMuted)
                }
            }
            .foregroundStyle(Theme.sheetText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(pending == i ? Theme.sheetPrimary.opacity(0.18) : Theme.sheetButton, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if isCurrent { RoundedRectangle(cornerRadius: 12).stroke(Theme.sheetPrimary, lineWidth: 1.5) }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(locked || pending != nil)
        .opacity(locked ? 0.5 : (pending != nil && pending != i ? 0.6 : 1))
        .accessibilityLabel(locked
            ? "\(i + 1)，\(name)，\(lockedText)"
            : "\(i + 1)，\(name)\(isCurrent ? String(localized: "，目前") : "")，\(rule)，" + String(localized: "模擬全破率 \(Self.simRates[i])"))
        .accessibilityIdentifier("difficulty.\(i)")
    }

    /// Inline confirmation when a run is in progress.
    private func confirm(_ lv: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SheetBody(text: Text("放棄目前這局，開始難度「\(Rules.difficulties[lv].name)」？"))
                .fontWeight(.bold)
                .accessibilityIdentifier("difficulty.confirmText")
            HStack(spacing: 8) {
                Button("再想想") { pending = nil }
                    .buttonStyle(SheetButtonStyle())
                    .accessibilityIdentifier("difficulty.confirmCancel")
                Button("放棄並開始") { pending = nil; pick(lv) }
                    .buttonStyle(SheetButtonStyle(primary: true))
                    .accessibilityIdentifier("difficulty.confirm")
            }
        }
    }
}
