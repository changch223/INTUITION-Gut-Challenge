//
//  SynthSounds.swift
//  BoomOrBonus
//
//  The prototype's WebAudio sounds (prototype.html `A`), rendered once into PCM buffers (no work at play time).
//  Each tone is an oscillator with an exponential gain ramp from `v` to 0.0001 over `d` seconds,
//  the same envelope WebAudio's `exponentialRampToValueAtTime` gives. Pure functions: easy to test, no AVFoundation.
//

import Foundation

enum Sfx: Hashable {
    case tick(Int)      // fuse tick, step 0...; pitch 620 + 110 * step
    case safe(Int)      // streak 1...; pitch rises with the streak (9 notes)
    case boom
    case shield         // shield block and defuse
    case goal           // goal reached
    case clear          // stage clear / bank
    case fail           // out of picks, target missed
    case coin           // purchase, new record
    case item           // item used, reroll

    /// Every sound the engine pre-renders. Tick steps and streaks beyond these reuse the last one.
    static let maxTick = 7
    static let all: [Sfx] =
        (0...maxTick).map { .tick($0) } + (1...9).map { .safe($0) } + [.boom, .shield, .goal, .clear, .fail, .coin, .item]

    var normalized: Sfx {
        switch self {
        case .tick(let s): return .tick(min(max(s, 0), Self.maxTick))
        case .safe(let n): return .safe(min(max(n, 1), 9))
        default: return self
        }
    }
}

enum SynthSounds {
    static let sampleRate = 44_100.0

    enum Wave { case sine, triangle, square, sawtooth }

    struct Tone {
        var freq: Double
        var dur: Double
        var wave: Wave
        var gain: Double
        var delay = 0.0
    }

    private static let safeNotes: [Double] = [523, 587, 659, 784, 880, 1047, 1175, 1319, 1568]

    static func tones(for sfx: Sfx) -> [Tone] {
        switch sfx.normalized {
        case .tick(let s):
            return [Tone(freq: 620 + Double(s) * 110, dur: 0.05, wave: .square, gain: 0.035)]
        case .safe(let n):
            let f = safeNotes[n - 1]
            return [Tone(freq: f, dur: 0.24, wave: .triangle, gain: 0.14),
                    Tone(freq: f * 1.5, dur: 0.32, wave: .sine, gain: 0.06, delay: 0.06)]
        case .boom:
            return [Tone(freq: 120, dur: 0.4, wave: .sawtooth, gain: 0.1)]     // plus the noise burst, see `render`
        case .shield:
            return [Tone(freq: 880, dur: 0.12, wave: .sine, gain: 0.1),
                    Tone(freq: 1320, dur: 0.26, wave: .sine, gain: 0.08, delay: 0.08)]
        case .goal:
            return [659, 784, 1047].enumerated().map { i, f in
                Tone(freq: f, dur: 0.18, wave: .triangle, gain: 0.1, delay: 0.14 + Double(i) * 0.08)
            }
        case .clear:
            return [523, 659, 784, 1047, 1319].enumerated().map { i, f in
                Tone(freq: f, dur: 0.26, wave: .triangle, gain: 0.12, delay: Double(i) * 0.09)
            }
        case .fail:
            return [392, 330, 262].enumerated().map { i, f in
                Tone(freq: f, dur: 0.3, wave: .sawtooth, gain: 0.06, delay: Double(i) * 0.14)
            }
        case .coin:
            return [Tone(freq: 1319, dur: 0.08, wave: .square, gain: 0.045),
                    Tone(freq: 1760, dur: 0.14, wave: .square, gain: 0.045, delay: 0.06)]
        case .item:
            return [Tone(freq: 988, dur: 0.1, wave: .triangle, gain: 0.1),
                    Tone(freq: 1319, dur: 0.12, wave: .triangle, gain: 0.08, delay: 0.07)]
        }
    }

    private static func sample(_ wave: Wave, phase p: Double) -> Double {
        let x = p - floor(p)     // 0..<1
        switch wave {
        case .sine: return sin(2 * .pi * x)
        case .triangle: return 4 * abs(x - 0.5) - 1
        case .square: return x < 0.5 ? 1 : -1
        case .sawtooth: return 2 * x - 1
        }
    }

    /// Mono samples at 44.1 kHz. Deterministic (the boom noise uses a fixed-seed generator).
    static func render(_ sfx: Sfx) -> [Float] {
        let tones = tones(for: sfx)
        let end = tones.map { $0.delay + $0.dur + 0.02 }.max() ?? 0.1
        var out = [Float](repeating: 0, count: Int(end * sampleRate) + 1)

        for tone in tones {
            let start = Int(tone.delay * sampleRate)
            let n = Int(tone.dur * sampleRate)
            let ratio = 0.0001 / tone.gain
            for i in 0..<n where start + i < out.count {
                let t = Double(i) / sampleRate
                let env = tone.gain * pow(ratio, t / tone.dur)
                out[start + i] += Float(env * sample(tone.wave, phase: tone.freq * t))
            }
        }

        if sfx == .boom {
            // 0.4 s of noise, amplitude (1 - t)^2, gain 0.28 (prototype `boom`).
            let n = Int(0.4 * sampleRate)
            var state: UInt32 = 0x1234_5678
            for i in 0..<min(n, out.count) {
                state = state &* 1_664_525 &+ 1_013_904_223
                let r = Double(state >> 8) / Double(1 << 24) * 2 - 1
                out[i] += Float(r * pow(1 - Double(i) / Double(n), 2) * 0.28)
            }
        }
        // Keep clear of clipping where the layers add up.
        for i in out.indices { out[i] = max(-1, min(1, out[i])) }
        return out
    }
}
