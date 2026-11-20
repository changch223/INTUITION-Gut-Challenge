//
//  SoundPlayer.swift
//  BoomOrBonus
//
//  Sound for the game (02-screens-ux.md §13). Two kinds:
//   - synthesized sounds (`Sfx`, ported from the prototype's WebAudio): rendered into PCM buffers once, off the
//     main thread, and played through an AVAudioEngine with a small pool of player nodes;
//   - the existing mp3 files that have no prototype equivalent (Click for button taps, start for a new run).
//  Neither ever blocks the main thread. The old AVAudioPlayer-per-call approach blocked it for seconds on the
//  simulator and cut every tick off, so every player is created once and `play` only enqueues work.
//  The audio session is `.ambient`: the user's music keeps playing and the silent switch is respected.
//  Interruptions (calls, Siri), route changes (AirPods) and media-services resets are handled by restarting the engine.
//

import AVFoundation
import Dispatch
import UIKit

@MainActor
final class SoundPlayer {
    private var players: [String: [AVAudioPlayer]] = [:]
    private var cursor: [String: Int] = [:]
    private let isMuted: () -> Bool
    private let synth = SynthEngine()

    /// True while an ad is on screen: the game stays silent, and the engine re-arms the session afterwards.
    var suspended = false {
        didSet { if oldValue, !suspended { synth.resume() } }
    }

    /// Click is used for taps, so it gets a small pool; the rest need one player.
    nonisolated private static let sounds: [(name: String, copies: Int)] = [
        ("Click", 3), ("start", 1),
    ]

    init(isMuted: @escaping () -> Bool) {
        self.isMuted = isMuted
        let synth = self.synth
        Task.detached(priority: .utility) {
            synth.start()
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

    /// An mp3 by file name.
    func play(_ name: String) {
        guard !isMuted(), !suspended, let list = players[name], !list.isEmpty else { return }
        let i = cursor[name, default: 0] % list.count
        cursor[name] = i + 1
        // play() can block for seconds on the simulator's audio stack, so it never runs on the main thread.
        let box = UncheckedBox(list[i])
        Self.queue.async {
            box.value.currentTime = 0
            box.value.play()
        }
    }

    /// A synthesized sound.
    func play(_ sfx: Sfx) {
        guard !isMuted(), !suspended else { return }
        synth.play(sfx)
    }

    private static let queue = DispatchQueue(label: "SoundPlayer.play", qos: .userInitiated)
}

/// Owns the AVAudioEngine. Everything runs on its own serial queue; the main thread only enqueues.
final class SynthEngine: @unchecked Sendable {
    private let queue = DispatchQueue(label: "SynthEngine", qos: .userInitiated)
    private var engine: AVAudioEngine?
    private var nodes: [AVAudioPlayerNode] = []
    private var buffers: [Sfx: AVAudioPCMBuffer] = [:]
    private var next = 0
    private var ready = false
    private var observers: [NSObjectProtocol] = []
    private var activeObserver: NSObjectProtocol?      // outlives `rebuild`
    private var lastRestartAt = Date.distantPast
    /// How many times the engine was (re)started or rebuilt after setup. Tests read it through `drain()`.
    private(set) var restartAttempts = 0
    /// At most one restart attempt per this many seconds, however many sounds are asked for in between.
    var restartThrottle: TimeInterval = 0.5
    private static let poolSize = 4
    /// A sound requested this long ago is dropped instead of played late (the engine was still starting).
    private static let maxLateness: TimeInterval = 0.4

    func start() {
        queue.async {
            self.setUp()
            // Coming back from the background: iOS stops the engine and does not always send an interruption-ended.
            let nc = NotificationCenter.default
            self.activeObserver = (nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
                self?.resume()
            })
        }
    }

    /// Tests: waits until everything queued so far has run.
    func drain() { queue.sync {} }

    /// Tests: whether sounds would play right now.
    var isReady: Bool { queue.sync { ready } }

    func play(_ sfx: Sfx) {
        let asked = Date()
        queue.async {
            guard Date().timeIntervalSince(asked) < Self.maxLateness else { return }
            // `.began` without an `.ended`, a failed start at launch, a stopped engine: try to come back, throttled.
            if !self.ready || self.engine?.isRunning != true {
                guard self.restartIfNeeded(throttled: true), self.ready else { return }
            }
            self.schedule(sfx.normalized)
        }
    }

    /// After an ad (or anything else that took the session): make sure we can play again.
    func resume() {
        queue.async { self.restartIfNeeded(throttled: false) }
    }

    // MARK: Queue-only

    private func setUp() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [])
        try? session.setActive(true)

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: SynthSounds.sampleRate,
                                         channels: 1, interleaved: false) else { return }
        for sfx in Sfx.all {
            let samples = SynthSounds.render(sfx)
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
                  let channel = buf.floatChannelData?[0] else { continue }
            samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
            buf.frameLength = AVAudioFrameCount(samples.count)
            buffers[sfx] = buf
        }

        let engine = AVAudioEngine()
        for _ in 0..<Self.poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            nodes.append(node)
        }
        self.engine = engine
        observe(session: session, engine: engine)
        ready = (try? engine.start()) != nil
    }

    private func observe(session: AVAudioSession, engine: AVAudioEngine) {
        let nc = NotificationCenter.default
        // A route change (AirPods in / out) reconfigures the engine and stops it.
        observers.append(nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            self?.queue.async { self?.restartIfNeeded(throttled: false) }
        })
        observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: nil) { [weak self] note in
            guard let self else { return }
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            self.queue.async {
                if type == .began { self.ready = false } else { self.restartIfNeeded(throttled: false) }
            }
        })
        // The media server died: every audio object is invalid, build it all again.
        observers.append(nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: nil) { [weak self] _ in
            self?.queue.async { self?.rebuild() }
        })
    }

    /// Re-arms the session and starts the engine if it is not running. Returns false when the throttle skipped it.
    @discardableResult
    private func restartIfNeeded(throttled: Bool) -> Bool {
        let now = Date()
        if throttled, now.timeIntervalSince(lastRestartAt) < restartThrottle { return false }
        lastRestartAt = now
        restartAttempts += 1
        guard let engine else { setUp(); return true }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [])
        try? session.setActive(true)
        if !engine.isRunning { ready = (try? engine.start()) != nil } else { ready = true }
        return true
    }

    private func rebuild() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        engine?.stop()
        engine = nil
        nodes.removeAll()
        ready = false
        setUp()
    }

    private func schedule(_ sfx: Sfx) {
        guard let buffer = buffers[sfx], !nodes.isEmpty, engine?.isRunning == true else { return }
        let node = nodes[next % nodes.count]
        next += 1
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }
}

private struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
