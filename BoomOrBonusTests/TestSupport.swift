//
//  TestSupport.swift
//  BoomOrBonusTests
//

import XCTest
@testable import BoomOrBonus

final class BundleToken {}

func loadVectors() throws -> [String: Any] {
    let bundle = Bundle(for: BundleToken.self)
    guard let url = bundle.url(forResource: "test-vectors", withExtension: "json") else {
        throw NSError(domain: "tests", code: 1, userInfo: [NSLocalizedDescriptionKey: "test-vectors.json not in test bundle"])
    }
    let data = try Data(contentsOf: url)
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

/// First seed whose stage-1 rule is the given mod (deterministic search).
func seedWithStage1Mod(_ mod: ModID) -> UInt32 {
    var s: UInt32 = 1
    while GameEngine.modAt(seed: s, stage: 1) != mod { s += 1 }
    return s
}

func boomCard(_ d: Int = 2) -> Card { Card(danger: d, p: 1, op: .add, n: 5, boom: true) }
func safeCard(n: Double = 5) -> Card { Card(danger: 1, p: 0, op: .add, n: n, boom: false) }
