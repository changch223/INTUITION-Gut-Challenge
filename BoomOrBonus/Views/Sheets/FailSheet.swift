//
//  FailSheet.swift
//  BoomOrBonus
//
//  02-screens-ux.md §5.1: out of picks without reaching the target.
//

import SwiftUI

struct FailSheet: View {
    let stage: Int
    let missing: Int
    let adState: GameViewModel.AdButtonState      // the rewarded ad: ready, still loading, or could not be loaded
    let endRun: () -> Void
    let watchAd: () -> Void

    var body: some View {
        SheetContainer {
            SheetTitle(
                small: Text("第 \(stage) 關 · 手數用完"),
                big: Text("還差 \(Fmt.int(missing)) 分")
            )
            SheetBody(text: Text("看一支獎勵廣告可以多拿 2 手，每局限一次。"))
            HStack(spacing: 8) {
                Button("結束這局", action: endRun)
                    .buttonStyle(SheetButtonStyle())
                    .accessibilityIdentifier("fail.end")
                Button(action: watchAd) {
                    switch adState {
                    case .ready: Text("看廣告，多 2 手")
                    case .loading: Text("廣告載入中…")
                    case .failed: Text("廣告暫時無法載入")
                    }
                }
                    .buttonStyle(SheetButtonStyle(primary: true))
                    .disabled(adState != .ready)
                    .opacity(adState == .ready ? 1 : 0.55)
                    .accessibilityIdentifier("fail.ad")
            }
            .padding(.top, 4)
        }
    }
}
