//
//  MenuSheet.swift
//  BoomOrBonus
//
//  The ? menu. Phase 4 only has what the daily challenge needs: sound on/off and 「放棄（算一次）」
//  (daily) / 「放棄這局」 (free), which asks first, inside the sheet (no system alert).
//  Phase 5 adds the rules sheet here (02 §8).
//

import SwiftUI

struct MenuSheet: View {
    let mode: Mode
    let attempt: Int
    let muted: Bool
    let toggleMute: () -> Void
    let abandon: () -> Void
    let close: () -> Void

    @State private var confirming = false

    var body: some View {
        SheetContainer {
            SheetTitle(small: Text("INTUITION++"), big: Text("選單"))
            // Phase 5 adds the rules sheet here

            Button(action: toggleMute) { Text(muted ? "開啟音效" : "關閉音效") }
                .buttonStyle(SheetButtonStyle())
                .accessibilityIdentifier("menu.mute")

            if confirming {
                confirmation
            } else {
                Button { confirming = true } label: { Text(mode == .daily ? "放棄（算一次）" : "放棄重來") }
                    .buttonStyle(SheetButtonStyle())
                    .accessibilityIdentifier("menu.abandon")
                Button("回到遊戲", action: close)
                    .buttonStyle(SheetButtonStyle(primary: true))
                    .accessibilityIdentifier("menu.close")
                    .padding(.top, 4)
            }
        }
    }

    /// Inline confirmation, so it can never be clipped or hidden behind a system alert.
    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 10) {
            SheetBody(text: mode == .daily
                ? Text("放棄這次挑戰？這次會算一次挑戰（即使一手都還沒選），接著開始第 \(attempt + 1) 次。")
                : Text("放棄這局？會換一副新牌重新開始。"))
                .fontWeight(.bold)
                .accessibilityIdentifier("menu.confirmText")
            HStack(spacing: 8) {
                Button("再想想") { confirming = false }
                    .buttonStyle(SheetButtonStyle())
                    .accessibilityIdentifier("menu.abandonCancel")
                Button("放棄", action: abandon)
                    .buttonStyle(SheetButtonStyle(primary: true))
                    .accessibilityIdentifier("menu.abandonConfirm")
            }
        }
    }
}
