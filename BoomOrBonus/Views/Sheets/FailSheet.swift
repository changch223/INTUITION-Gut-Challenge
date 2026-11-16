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
                Button("看廣告，多 2 手", action: watchAd)
                    .buttonStyle(SheetButtonStyle(primary: true))
                    .accessibilityIdentifier("fail.ad")
            }
            .padding(.top, 4)
        }
    }
}
