//
//  SaveStore.swift
//  BoomOrBonus
//
//  SaveData (03-data-persistence.md §2) as one JSON file in Application Support.
//  Phase 2 only stores runs.free, lastLevel, muted, onboardingDone.
//  Every field decodes with a default so later phases can add fields
//  (daily, unlock, deepest, stats...) without invalidating existing saves.
//

import Foundation

struct SaveData: Codable, Equatable {
    struct Runs: Codable, Equatable {
        var free: RunState?
        var daily: RunState?     // Phase 4

        init(free: RunState? = nil, daily: RunState? = nil) {
            self.free = free
            self.daily = daily
        }

        private enum CodingKeys: String, CodingKey { case free, daily }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // A run that no longer decodes must not take the settings down with it.
            free = (try? c.decodeIfPresent(RunState.self, forKey: .free)) ?? nil
            daily = (try? c.decodeIfPresent(RunState.self, forKey: .daily)) ?? nil
        }
    }

    var runs = Runs()
    var lastLevel = 0
    var muted = false
    var onboardingDone = false

    init() {}

    private enum CodingKeys: String, CodingKey { case runs, lastLevel, muted, onboardingDone }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runs = try c.decodeIfPresent(Runs.self, forKey: .runs) ?? Runs()
        lastLevel = try c.decodeIfPresent(Int.self, forKey: .lastLevel) ?? 0
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false
        onboardingDone = try c.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? false
    }
}

final class SaveStore {
    /// RunState.version this build understands (03 §1: currently 6).
    static let runVersion = 6

    static let shared = SaveStore(url: SaveStore.defaultURL())

    private let url: URL?
    private(set) var data: SaveData

    /// `url == nil` keeps everything in memory (tests, previews).
    init(url: URL?) {
        self.url = url
        if let url, let raw = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) {
            data = decoded
        } else {
            data = SaveData()
        }
    }

    static func defaultURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return dir.appendingPathComponent("save-v6.json")
    }

    func update(_ change: (inout SaveData) -> Void) {
        change(&data)
        write()
    }

    private func write() {
        guard let url, let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: url, options: .atomic)
    }

    /// 03 §2.1: same version, and phase is play or shop (shop re-opens the stage-clear screen).
    /// Phase 2 has no daily mode, so the day check does not apply.
    func restorableFreeRun() -> RunState? {
        guard let run = data.runs.free else { return nil }
        guard run.version == Self.runVersion else { return nil }
        guard run.phase == .play || run.phase == .shop else { return nil }
        guard run.pair.count == 2 else { return nil }
        return run
    }
}
