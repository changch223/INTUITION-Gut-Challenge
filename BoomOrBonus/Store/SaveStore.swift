//
//  SaveStore.swift
//  BoomOrBonus
//
//  SaveData (03-data-persistence.md §2) as one JSON file in Application Support.
//  Phase 3 adds unlock and deepest (Phase 2: runs.free, lastLevel, muted, onboardingDone).
//  Phase 4 adds runs.daily, daily[YYYYMMDD] (DailyRecord) and the mode the player was last in.
//  Phase 6 adds stats (cumulative numbers and personal records, Stats.swift).
//  Every field decodes with a default so later phases can add fields
//  (daily, unlock, deepest, stats...) without invalidating existing saves.
//

import Foundation

struct SaveData: Codable, Equatable {
    struct Runs: Codable, Equatable {
        var free: RunState?
        var daily: RunState?

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
    var unlock = 0           // highest unlocked difficulty, 0...5
    var deepest = 0          // endless: most stages cleared (marks > 0) in one run
    var muted = false
    var onboardingDone = false
    var daily: [Int: DailyRecord] = [:]   // 03 §3, keyed by YYYYMMDD (stored as string keys in the JSON)
    var mode: Mode?                       // the mode the player was last in; nil = never saved (new install)
    var stats = Stats()                   // 03 §4: cumulative numbers and personal records

    init() {}

    private enum CodingKeys: String, CodingKey { case runs, lastLevel, unlock, deepest, muted, onboardingDone, daily, mode, stats }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runs = try c.decodeIfPresent(Runs.self, forKey: .runs) ?? Runs()
        lastLevel = try c.decodeIfPresent(Int.self, forKey: .lastLevel) ?? 0
        unlock = min(5, max(0, try c.decodeIfPresent(Int.self, forKey: .unlock) ?? 0))
        deepest = max(0, try c.decodeIfPresent(Int.self, forKey: .deepest) ?? 0)
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false
        onboardingDone = try c.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? false
        // One unreadable day must not take the others down: decode day by day, skip what does not parse.
        let raw = (try? c.decodeIfPresent([String: LossyDaily].self, forKey: .daily)) ?? [:]
        for (k, v) in raw { if let day = Int(k), let r = v.record { daily[day] = r } }
        mode = (try? c.decodeIfPresent(Mode.self, forKey: .mode)) ?? nil
        stats = (try? c.decodeIfPresent(Stats.self, forKey: .stats)) ?? Stats()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(runs, forKey: .runs)
        try c.encode(lastLevel, forKey: .lastLevel)
        try c.encode(unlock, forKey: .unlock)
        try c.encode(deepest, forKey: .deepest)
        try c.encode(muted, forKey: .muted)
        try c.encode(onboardingDone, forKey: .onboardingDone)
        try c.encode(Dictionary(uniqueKeysWithValues: daily.map { (String($0.key), $0.value) }), forKey: .daily)
        try c.encodeIfPresent(mode, forKey: .mode)
        try c.encode(stats, forKey: .stats)
    }

    private struct LossyDaily: Decodable {
        let record: DailyRecord?
        init(from decoder: Decoder) throws { record = try? DailyRecord(from: decoder) }
    }
}

final class SaveStore {
    /// RunState.version this build understands (03 §1: currently 6).
    static let runVersion = 6

    /// Debug builds only: the unit-test host app keeps everything in memory (never reads or writes the real save).
    /// `-seed` (QA / UI tests) uses `save-qa.json`, wiped at launch, so the real
    /// `save-v6.json` is never touched. `-qaSave` (without `-seed`) re-opens `save-qa.json` as it is,
    /// to test kill / relaunch. Release builds always use the real file.
    static let shared: SaveStore = {
        #if DEBUG
        if TestHost.isUnitTesting { return SaveStore(url: nil) }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-seed") || args.contains("-qaSave"), let url = qaURL() {
            if args.contains("-seed") { try? FileManager.default.removeItem(at: url) }
            return SaveStore(url: url)
        }
        #endif
        return SaveStore(url: defaultURL())
    }()

    static func qaURL() -> URL? {
        defaultURL()?.deletingLastPathComponent().appendingPathComponent("save-qa.json")
    }

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

    /// 03 §2.1: same version, and phase is play or shop (shop re-opens the shop with the same shelf).
    func restorableFreeRun() -> RunState? { restorableRun(.free, today: 0) }

    /// 03 §2.1 for either mode. A daily run also needs `day == today`: after midnight yesterday's run is void.
    func restorableRun(_ mode: Mode, today: Int) -> RunState? {
        guard let run = mode == .daily ? data.runs.daily : data.runs.free else { return nil }
        guard run.mode == mode, run.version == Self.runVersion else { return nil }
        guard run.phase == .play || run.phase == .shop else { return nil }
        guard run.pair.count == 2 else { return nil }
        if mode == .daily && run.day != today { return nil }
        return run
    }
}
