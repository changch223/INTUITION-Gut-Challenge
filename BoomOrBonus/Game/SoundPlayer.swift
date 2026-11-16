//
//  SoundPlayer.swift
//  BoomOrBonus
//
//  Sound for the new game code only (AudioManager stays as is for the old screens).
//  AudioManager builds a fresh AVAudioPlayer on every call, which blocked the main thread
//  for seconds on the simulator and cut each tick off. Here every player is created once,
//  off the main thread, and the pick flow only calls play().
//

import AVFoundation
import Dispatch

@MainActor
final class SoundPlayer {
    private var players: [String: [AVAudioPlayer]] = [:]
    private var cursor: [String: Int] = [:]
    private let isMuted: () -> Bool

    /// Tick overlaps itself, so it gets a small pool; the rest need one player.
    nonisolated private static let sounds: [(name: String, copies: Int)] = [
        ("Click", 3), ("ButtonSuccess", 1), ("ButtonFail", 1), ("start", 1),
    ]

    init(isMuted: @escaping () -> Bool) {
        self.isMuted = isMuted
        Task.detached(priority: .utility) {
            var built: [String: [AVAudioPlayer]] = [:]
            for (name, copies) in Self.sounds {
                guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { continue }
                var list: [AVAudioPlayer] = []
                for _ in 0..<copies {
                    if let p = try? AVAudioPlayer(contentsOf: url) {
                        p.prepareToPlay()
                        list.append(p)
                    }
                }
                built[name] = list
            }
            // AVAudioPlayer is not Sendable; the players are handed over once and never shared.
            let handoff = UncheckedBox(built)
            await MainActor.run { self.players = handoff.value }
        }
    }

    func play(_ name: String) {
        guard !isMuted(), let list = players[name], !list.isEmpty else { return }
        let i = cursor[name, default: 0] % list.count
        cursor[name] = i + 1
        // play() can block for seconds on the simulator's audio stack, so it never runs on the main thread.
        let box = UncheckedBox(list[i])
        Self.queue.async {
            box.value.currentTime = 0
            box.value.play()
        }
    }

    private static let queue = DispatchQueue(label: "SoundPlayer.play", qos: .userInitiated)
}

private struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
