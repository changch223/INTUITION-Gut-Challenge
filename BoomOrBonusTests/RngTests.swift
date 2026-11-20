//
//  RngTests.swift
//  BoomOrBonusTests
//

import XCTest
@testable import BoomOrBonus

final class RngTests: XCTestCase {
    func testMulberry32() throws {
        let v = try loadVectors()["mulberry32"] as! [String: [Double]]
        XCTAssertEqual(Set(v.keys), ["seed1", "seed20261116"])
        for (key, expected) in v {
            let seed = UInt32(key.dropFirst("seed".count))!
            var r = Mulberry32(seed)
            for e in expected {
                XCTAssertEqual(r.next(), e, accuracy: 1e-12, key)
            }
        }
    }

    func testSeedOf() throws {
        let v = try loadVectors()["seedOf"] as! [String: Int]
        XCTAssertEqual(v.count, 4)
        for (key, expected) in v {
            let xs = key.split(separator: ",").map { Int($0)! }
            let got: UInt32
            switch xs.count {
            case 3: got = seedOf(xs[0], xs[1], xs[2])
            case 4: got = seedOf(xs[0], xs[1], xs[2], xs[3])
            default: XCTFail("bad key \(key)"); continue
            }
            XCTAssertEqual(Int(got), expected, key)
        }
    }
}
