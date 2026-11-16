//
//  ToastView.swift
//  BoomOrBonus
//
//  02-screens-ux.md §6: dark capsule near the top.
//

import SwiftUI

struct ToastView: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Theme.deepNight, in: RoundedRectangle(cornerRadius: 20))
            .frame(maxWidth: 340)
            .allowsHitTesting(false)
    }
}
