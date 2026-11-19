//
//  Stats.swift
//  BoomOrBonus
//
//  Cumulative numbers and personal records (03-data-persistence.md §4), plus the milestone math of
//  the records page (02-screens-ux.md §10) and the clearly labelled sample data shown while there is no data.
//  Foundation only. Every field decodes with a default, so SaveData can add `stats` without invalidating old saves.
//

import Foundation

// MARK: - Records

/// The six personal records (03 §4.2). Raw values are what RunState.brokenRecords stores.
enum RecordID: String, Codable, CaseIterable, Hashable, CodingKeyRepresentable {
    case total, stage, pick, streak, deep, coins

    var name: String {
        switch self {
        case .total: return String(localized: "單局最高總分")
        case .stage: return String(localized: "單關最高分")
        case .pick: return String(localized: "單手最高得分")
        case .streak: return String(localized: "最長連中")
        case .deep: return String(localized: "最多過關數")
        case .coins: return String(localized: "單局賺到最多金幣")
        }
    }

    /// The one-line explanation of what counts (prototype RECN[k][2]).
    var note: String {
        switch self {
        case .total: return String(localized: "各關分數加總，含無盡關卡")
        case .stage: return String(localized: "一關之內打到的分數")
        case .pick: return String(localized: "一張牌一次拿到的分數，倍數牌加上雙倍道具最容易破")
        case .streak: return String(localized: "連中會跨關延續，爆炸就重算")
        case .deep: return String(localized: "6 是破關，之後算無盡關卡")
        case .coins: return String(localized: "過關獎勵的加總，不扣花掉的")
        }
    }

    /// Ascending targets to chase (03 §4.2).
    var milestones: [Int] {
        switch self {
        case .total: return [100, 250, 500, 800, 1200]
        case .stage: return [30, 60, 100, 160, 250, 400]
        case .pick: return [10, 20, 40, 80, 150]
        case .streak: return [3, 5, 8, 12, 16, 20]
        case .deep: return [3, 6, 8, 10, 12, 15]
        case .coins: return [10, 20, 35, 50, 80]
        }
    }
}

struct RecordEntry: Codable, Equatable {
    var value: Int
    var day: Int          // YYYYMMDD it was set on
}

/// Where a value stands on a record's milestone list (the bar and 「下一個目標 X　已達成數 / 總數」).
struct MilestoneProgress: Equatable {
    let achieved: Int         // milestones with value >= m
    let total: Int
    let next: Int?            // nil = all achieved
    let fraction: Double      // 0...1, (value - previous) / (next - previous); 1 when all achieved

    static func of(_ value: Int, in milestones: [Int]) -> MilestoneProgress {
        let achieved = milestones.filter { value >= $0 }.count
        guard let next = milestones.first(where: { value < $0 }) else {
            return MilestoneProgress(achieved: achieved, total: milestones.count, next: nil, fraction: 1)
        }
        let previous = achieved > 0 ? milestones[achieved - 1] : 0
        let f = Double(value - previous) / Double(max(1, next - previous))
        return MilestoneProgress(achieved: achieved, total: milestones.count, next: next, fraction: min(1, max(0, f)))
    }
}

// MARK: - Stats

struct Stats: Codable, Equatable {
    /// `{runs, clears, best}` of one difficulty, or of the daily challenge.
    struct Tally: Codable, Equatable {
        var runs = 0
        var clears = 0
        var best = 0

        init(runs: Int = 0, clears: Int = 0, best: Int = 0) {
            self.runs = runs
            self.clears = clears
            self.best = best
        }

        private enum CodingKeys: String, CodingKey { case runs, clears, best }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            runs = max(0, try c.decodeIfPresent(Int.self, forKey: .runs) ?? 0)
            clears = max(0, try c.decodeIfPresent(Int.self, forKey: .clears) ?? 0)
            best = max(0, try c.decodeIfPresent(Int.self, forKey: .best) ?? 0)
        }
    }

    /// `{runs, wins}` of one blessing.
    struct BlessingTally: Codable, Equatable {
        var runs = 0
        var wins = 0

        init(runs: Int = 0, wins: Int = 0) {
            self.runs = runs
            self.wins = wins
        }

        private enum CodingKeys: String, CodingKey { case runs, wins }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            runs = max(0, try c.decodeIfPresent(Int.self, forKey: .runs) ?? 0)
            wins = max(0, try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0)
        }
    }

    var runs = 0                  // runs finished, abandons included (counted once per run)
    var abandons = 0
    var clears = 0                // runs that cleared all six stages
    var allSuper = 0              // runs where all six stages were stretch clears
    var picks = 0                 // every reveal
    var safe = 0
    var booms = 0
    var shields = 0               // explosions stopped by a shield or the defuse blessing
    var byLevel: [Tally]          // free play, index = difficulty 0...5
    var daily = Tally()           // the daily challenge
    var byBlessing: [BlessingID: BlessingTally] = [:]
    var records: [RecordID: RecordEntry] = [:]

    init() {
        byLevel = Array(repeating: Tally(), count: Rules.difficulties.count)
    }

    private enum CodingKeys: String, CodingKey {
        case runs, abandons, clears, allSuper, picks, safe, booms, shields, byLevel, daily, byBlessing, records
    }

    /// Every field decodes on its own: one wrong-typed or unknown piece costs only itself, never the rest.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func n(_ k: CodingKeys) -> Int { max(0, (try? c.decodeIfPresent(Int.self, forKey: k)) ?? 0) }
        runs = n(.runs)
        abandons = n(.abandons)
        clears = n(.clears)
        allSuper = n(.allSuper)
        picks = n(.picks)
        safe = n(.safe)
        booms = n(.booms)
        shields = n(.shields)
        var levels = ((try? c.decodeIfPresent([Lossy<Tally>].self, forKey: .byLevel)) ?? nil)?.map { $0.value ?? Tally() } ?? []
        if levels.count < Rules.difficulties.count {
            levels += Array(repeating: Tally(), count: Rules.difficulties.count - levels.count)
        }
        byLevel = Array(levels.prefix(Rules.difficulties.count))
        daily = ((try? c.decodeIfPresent(Tally.self, forKey: .daily)) ?? nil) ?? Tally()
        // Keyed by raw id strings: an id this build does not know (or an entry that does not parse) is skipped.
        let blessings = ((try? c.decodeIfPresent([String: Lossy<BlessingTally>].self, forKey: .byBlessing)) ?? nil) ?? [:]
        for (k, v) in blessings { if let id = BlessingID(rawValue: k), let t = v.value { byBlessing[id] = t } }
        let recs = ((try? c.decodeIfPresent([String: Lossy<RecordEntry>].self, forKey: .records)) ?? nil) ?? [:]
        for (k, v) in recs { if let id = RecordID(rawValue: k), let e = v.value { records[id] = e } }
    }

    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    // MARK: Records

    func value(_ id: RecordID) -> Int? { records[id]?.value }

    /// 03 §4.2: only a strictly higher value breaks a record. A value of 0 or less is never a record
    /// (a run that earned no coins has nothing to chase). Returns true when the record was set or raised.
    @discardableResult
    mutating func raise(_ id: RecordID, to value: Int, day: Int) -> Bool {
        guard value > 0, value > (records[id]?.value ?? 0) else { return false }
        records[id] = RecordEntry(value: value, day: day)
        return true
    }

    func progress(_ id: RecordID) -> MilestoneProgress {
        MilestoneProgress.of(records[id]?.value ?? 0, in: id.milestones)
    }

    /// Milestones reached over all six records (not shown on the page, handy for tests).
    var achievedTotal: Int { RecordID.allCases.reduce(0) { $0 + progress($1).achieved } }

    // MARK: Counters

    /// A reveal (03 §4.1): picks always, then safe / booms / shields.
    mutating func countPick(_ event: PickEvent) {
        picks += 1
        switch event {
        case .safe: safe += 1
        case .boom: booms += 1
        case .shield, .defuse: shields += 1
        }
    }

    /// The run-level counters, once per run (the caller guards with `statsCounted`).
    mutating func countRun(mode: Mode, lv: Int, won: Bool, allSuper isAllSuper: Bool,
                           abandoned: Bool, blessings: [BlessingID]) {
        runs += 1
        if abandoned { abandons += 1 }
        if won { clears += 1 }
        if isAllSuper { allSuper += 1 }
        for b in blessings {
            var t = byBlessing[b] ?? BlessingTally()
            t.runs += 1
            if won { t.wins += 1 }
            byBlessing[b] = t
        }
        if mode == .daily {
            daily.runs += 1
            if won { daily.clears += 1 }
        } else if byLevel.indices.contains(lv) {
            byLevel[lv].runs += 1
            if won { byLevel[lv].clears += 1 }
        }
    }

    /// Best total of a difficulty or of the daily challenge, on every finish (an endless re-finish included).
    mutating func raiseBest(mode: Mode, lv: Int, total: Int) {
        if mode == .daily {
            daily.best = max(daily.best, total)
        } else if byLevel.indices.contains(lv) {
            byLevel[lv].best = max(byLevel[lv].best, total)
        }
    }
}

// MARK: - Sample data

/// What 「先看範例」 shows while there is no data (prototype `sampleData()`). Always labelled as a sample
/// in the UI; never written to the save by the app (only the `-stats sample` debug hook does that).
enum SampleData {
    static func make(today: Int) -> (stats: Stats, daily: [Int: DailyRecord], unlock: Int) {
        func ago(_ n: Int) -> Int { DayKey.adding(-n, to: today) }
        var s = Stats()
        s.runs = 23; s.clears = 4; s.picks = 301; s.safe = 201; s.booms = 84; s.shields = 16
        s.abandons = 3; s.allSuper = 0
        s.records = [
            .total: RecordEntry(value: 1040, day: ago(3)),
            .stage: RecordEntry(value: 212, day: ago(3)),
            .pick: RecordEntry(value: 64, day: ago(6)),
            .streak: RecordEntry(value: 11, day: ago(1)),
            .deep: RecordEntry(value: 8, day: ago(3)),
            .coins: RecordEntry(value: 41, day: ago(9)),
        ]
        s.byLevel[0] = Stats.Tally(runs: 15, clears: 3, best: 912)
        s.byLevel[1] = Stats.Tally(runs: 5, clears: 1, best: 1040)
        s.byLevel[2] = Stats.Tally(runs: 3, clears: 0, best: 388)
        s.daily = Stats.Tally(runs: 31, clears: 7, best: 1180)
        s.byBlessing = [
            .add: Stats.BlessingTally(runs: 12, wins: 1),
            .grit: Stats.BlessingTally(runs: 9, wins: 2),
            .snow: Stats.BlessingTally(runs: 7, wins: 2),
            .cool: Stats.BlessingTally(runs: 6, wins: 1),
            .bank: Stats.BlessingTally(runs: 5, wins: 0),
        ]
        var log: [Int: DailyRecord] = [:]
        // (days ago, tries, won)
        for (n, tries, won) in [(0, 3, false), (1, 2, true), (2, 4, true), (3, 1, true), (5, 5, false),
                                (6, 3, true), (8, 2, true), (9, 6, false), (10, 3, true), (12, 2, true)] {
            var r = DailyRecord()
            r.tries = tries
            r.win = won
            r.winTry = won ? tries : 0
            r.hist = (0..<tries).map { i in
                DailyRecord.Attempt(cleared: won && i == tries - 1 ? Rules.STAGES : min(5, 1 + i + n % 2), total: 0)
            }
            log[ago(n)] = r
        }
        return (s, log, 2)
    }
}
