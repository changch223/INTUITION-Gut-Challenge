//
//  EngineVectorTests.swift
//  BoomOrBonusTests
//

import XCTest
@testable import BoomOrBonus

final class EngineVectorTests: XCTestCase {
    var vectors: [String: Any] = [:]

    override func setUpWithError() throws {
        vectors = try loadVectors()
    }

    func testAllVectorKeysAreCovered() {
        let covered: Set<String> = [
            "mulberry32", "seedOf", "nice", "targets", "stageRule_seed20261116",
            "genPair_daily20261116_stage1_value0", "genPair_daily20261116_stage1_value10",
            "genPair_daily20261116_stage2_fog_value10",
            "shopOffer_20261116_stage1_srr0", "shopOffer_20261116_stage1_srr1",
            "stagePicks_lv2_stage8_short",
        ]
        XCTAssertEqual(Set(vectors.keys), covered, "test-vectors.json has keys this suite does not cover")
    }

    func testNice() {
        let v = vectors["nice"] as! [String: Int]
        XCTAssertFalse(v.isEmpty)
        for (key, expected) in v {
            XCTAssertEqual(GameEngine.nice(Double(key)!), expected, key)
        }
    }

    func testTargets() {
        let v = vectors["targets"] as! [String: [Int]]
        XCTAssertEqual(v.count, 7)
        for (key, expected) in v {
            if key.hasPrefix("lv") {
                let lv = Int(key.dropFirst(2))!
                let got = (1...expected.count).map { GameEngine.targetAt(stage: $0, lv: lv) }
                XCTAssertEqual(got, expected, key)
            } else if key == "daily_20261116" {
                let run = GameEngine.newRun(seed: 20261116, lv: 0, mode: .daily, targetMul: Rules.DAILY_TM)
                let got = (1...expected.count).map { GameEngine.targetOf(run, stage: $0) }
                XCTAssertEqual(got, expected, key)
            } else {
                XCTFail("unknown targets key \(key)")
            }
        }
    }

    func testStageRules() {
        let v = vectors["stageRule_seed20261116"] as! [String]
        XCTAssertEqual(v.count, 12)
        for (i, expected) in v.enumerated() {
            let stage = i + 1
            let got: String
            if let boss = GameEngine.bossOf(stage: stage) {
                got = "boss:\(boss.rawValue)"
            } else if let mod = GameEngine.modAt(seed: 20261116, stage: stage) {
                got = "mod:\(mod.rawValue)"
            } else {
                got = "none"
            }
            XCTAssertEqual(got, expected, "stage \(stage)")
        }
    }

    private func checkPairs(key: String, stage: Int, value: Int) {
        let entry = vectors[key] as! [String: Any]
        let pairs = entry["pairs"] as! [[[String: Any]]]
        XCTAssertEqual(pairs.count, 5, key)
        var run = GameEngine.newRun(seed: 20261116, lv: 0, mode: .daily, targetMul: Rules.DAILY_TM)
        run.stage = stage
        run.value = value
        for (idx, expectedPair) in pairs.enumerated() {
            run.idx = idx
            run.rerolls = 0
            let got = GameEngine.genPair(run)
            XCTAssertEqual(got.count, 2)
            for (k, e) in expectedPair.enumerated() {
                let c = got[k]
                let tag = "\(key) idx \(idx) card \(k)"
                XCTAssertEqual(c.danger, e["d"] as! Int, tag + " d")
                XCTAssertEqual(c.p, e["p"] as! Double, accuracy: 1e-12, tag + " p")
                XCTAssertEqual(c.op == .add ? "+" : "\u{00D7}", e["op"] as! String, tag + " op")
                XCTAssertEqual(c.n, e["n"] as! Double, accuracy: 1e-12, tag + " n")
                XCTAssertEqual(c.boom, e["boom"] as! Bool, tag + " boom")
                XCTAssertEqual(c.fog, (e["fog"] as? Bool) ?? false, tag + " fog")
            }
        }
    }

    func testGenPairStage1Value0() { checkPairs(key: "genPair_daily20261116_stage1_value0", stage: 1, value: 0) }
    func testGenPairStage1Value10() { checkPairs(key: "genPair_daily20261116_stage1_value10", stage: 1, value: 10) }
    func testGenPairStage2FogValue10() { checkPairs(key: "genPair_daily20261116_stage2_fog_value10", stage: 2, value: 10) }

    func testShopOffers() {
        var run = GameEngine.newRun(seed: 20261116, lv: 0, mode: .daily, targetMul: Rules.DAILY_TM)
        run.stage = 1
        run.shopRerolls = 0
        XCTAssertEqual(Shop.shopOffer(run).map(\.rawValue), vectors["shopOffer_20261116_stage1_srr0"] as! [String])
        run.shopRerolls = 1
        XCTAssertEqual(Shop.shopOffer(run).map(\.rawValue), vectors["shopOffer_20261116_stage1_srr1"] as! [String])
    }

    func testStagePicksLv2Stage8Short() {
        var run = GameEngine.newRun(seed: 20261116, lv: 2, mode: .free)
        run.stage = 8
        XCTAssertEqual(GameEngine.bossOf(stage: 8), .short)
        XCTAssertEqual(GameEngine.stagePicks(run), vectors["stagePicks_lv2_stage8_short"] as! Int)
    }
}
