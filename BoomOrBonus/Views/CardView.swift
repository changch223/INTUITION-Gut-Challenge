//
//  CardView.swift
//  BoomOrBonus
//
//  02-screens-ux.md §2.6 and §3: add / multiplier / fog faces, fuse cells, peek tag,
//  armed (fuse blinking), dimmed, and the reveal faces (safe / boom / saved).
//

import SwiftUI

struct CardView: View {
    let face: GameViewModel.CardFace
    let isArmed: Bool
    let isDimmed: Bool
    let reveal: GameViewModel.Reveal?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blink = false

    private var card: Card { face.card }
    private var isFog: Bool { card.fog }
    private var isMul: Bool { card.op == .mul && !isFog }
    private var dangerColor: Color { isFog ? Theme.fog : Theme.danger(card.danger) }

    var body: some View {
        Button(action: action) {
            ZStack {
                content
                    .opacity(reveal == nil ? 1 : 0)
                if let reveal {
                    result(reveal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
            .background { background }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(CardPressStyle())
        .scaleEffect(scale)
        .opacity(isDimmed ? 0.35 : 1)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.6),
                   value: reveal)
        .animation(.easeOut(duration: reduceMotion ? 0.1 : 0.16), value: isArmed)
        .animation(.easeOut(duration: 0.2), value: isDimmed)
        .onChange(of: isArmed) { _, armed in updateBlink(armed) }
        .accessibilityLabel(accessibilityText)
    }

    private var scale: CGFloat {
        if reveal != nil { return 1 }
        if isArmed { return 1.04 }
        if isDimmed { return 0.96 }
        return 1
    }

    private func updateBlink(_ armed: Bool) {
        if armed && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.11).repeatForever(autoreverses: true)) { blink = true }
        } else {
            withAnimation(.linear(duration: 0)) { blink = false }
        }
    }

    // MARK: Faces

    @ViewBuilder
    private var background: some View {
        switch reveal {
        case .safe: Theme.mint
        case .boom: Theme.red
        case .shield, .defuse: Theme.shieldSaved
        case nil:
            if isFog { FogStripes() } else if isMul { Theme.night } else { Theme.ink }
        }
    }

    /// The full face, or a compact one when the card is short (iPhone SE).
    private var content: some View {
        ViewThatFits(in: .vertical) {
            faceView(compact: false)
            faceView(compact: true)
        }
    }

    private func faceView(compact: Bool) -> some View {
        let textColor = isMul ? Theme.ink : Theme.night
        return VStack(spacing: compact ? 1 : 3) {
            HStack(spacing: 6) {
                Text(isFog ? "蓋住的牌" : (card.op == .add ? "加分" : "倍數"))
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1.2)
                    .opacity(0.6)
                if face.peek {
                    Text(card.boom ? "會爆" : "安全")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(card.boom ? Theme.danger4 : Theme.danger1, in: Capsule())
                }
            }
            .frame(height: 20)
            Text(isFog ? "?" : bigNumber)
                .font(Theme.number(compact ? 44 : (isFog ? 64 : 60)))
                .tracking(-1.8)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(isMul ? Theme.gold : textColor)
                .opacity(isFog ? 0.55 : 1)
            Text(isFog ? "翻開才知道" : "成功 → \(Fmt.int(face.preview))")
                .font(.system(size: 12.5).monospacedDigit())
                .opacity(0.7)
                .padding(.bottom, compact ? 3 : 10)
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(!isFog && i <= card.danger ? dangerColor : Color(hex: 0x8088B8, opacity: 0.28))
                        .frame(width: 22, height: 8)
                        .opacity(isArmed && !isFog && i <= card.danger && blink ? 0.25 : 1)
                }
            }
            Text(isFog ? "危險 ？" : "危險 \(card.danger) · \(Int((card.p * 100).rounded()))%")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(dangerColor)
                .padding(.top, compact ? 2 : 5)
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 8).padding(.vertical, compact ? 6 : 12)
    }

    private var bigNumber: String {
        card.op == .add ? "+\(Fmt.int(Int(card.n)))" : "×\(Fmt.num(card.n))"
    }

    private func result(_ r: GameViewModel.Reveal) -> some View {
        VStack(spacing: 6) {
            switch r {
            case .safe(let delta):
                Text("+\(Fmt.int(delta))").font(Theme.number(34)).foregroundStyle(Color(hex: 0x062A20))
            case .boom(let lost):
                Group {
                    if lost > 0 { Text("爆了 −\(Fmt.int(lost))") } else { Text("爆了") }
                }
                .font(Theme.number(34)).foregroundStyle(.white)
                Text("扣 1 手").font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
            case .shield:
                Text("保命符擋下").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.night)
                Text("不扣手數").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.night)
            case .defuse:
                Text("拆彈成功").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.night)
                Text("不扣手數").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.night)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.6)
        .padding(8)
    }

    // MARK: VoiceOver

    private var accessibilityText: String {
        if let reveal {
            switch reveal {
            case .safe(let d): return String(localized: "安全，得 \(d) 分")
            case .boom(let lost): return lost > 0 ? String(localized: "爆炸，扣 1 手，分數減 \(lost)") : String(localized: "爆炸，扣 1 手")
            case .shield: return String(localized: "保命符擋下，不扣手數")
            case .defuse: return String(localized: "拆彈成功，不扣手數")
            }
        }
        var text: String
        if isFog {
            text = String(localized: "蓋住的牌，分數和危險度不明")
        } else {
            let pct = Int((card.p * 100).rounded())
            if card.op == .add {
                text = String(localized: "加 \(Int(card.n)) 分，危險度 \(card.danger) 格，爆炸機率 \(pct)%")
            } else {
                text = String(localized: "乘 \(Fmt.num(card.n))，危險度 \(card.danger) 格，爆炸機率 \(pct)%")
            }
        }
        if face.peek { text += card.boom ? String(localized: "，透視：會爆") : String(localized: "，透視：安全") }
        return text
    }
}

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Grey diagonal stripes, 10pt each (prototype .fogc).
private struct FogStripes: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.fogStripeA))
            let h = size.height
            var x = -h
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x + 10, y: 0))
                p.addLine(to: CGPoint(x: x + 20, y: 0))
                p.addLine(to: CGPoint(x: x + 20 + h, y: h))
                p.addLine(to: CGPoint(x: x + 10 + h, y: h))
                p.closeSubpath()
                ctx.fill(p, with: .color(Theme.fogStripeB))
                x += 20
            }
        }
    }
}
