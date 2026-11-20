import XCTest
@testable import CarPlaySyncKit

final class VectorClockTests: XCTestCase {
    func testCausalBeforeAfterAndEqualOrdering() {
        let c0 = VectorClock()
        let c1 = c0.incrementing(nodeID: "iphone-host")
        let c2 = c1.incrementing(nodeID: "carplay-headunit")

        XCTAssertEqual(c0.compare(to: c0), .equal)
        XCTAssertEqual(c1.compare(to: c2), .before)
        XCTAssertEqual(c2.compare(to: c1), .after)
    }

    func testConcurrentDivergenceAndMergeDominatesBoth() {
        let base = VectorClock(counters: ["iphone-host": 1, "carplay-headunit": 1])
        let phoneBranch = base.incrementing(nodeID: "iphone-host")
        let headUnitBranch = base.incrementing(nodeID: "carplay-headunit")

        XCTAssertEqual(phoneBranch.compare(to: headUnitBranch), .concurrent)
        XCTAssertEqual(headUnitBranch.compare(to: phoneBranch), .concurrent)

        let merged = phoneBranch.merged(with: headUnitBranch)
        XCTAssertEqual(merged["iphone-host"], 2)
        XCTAssertEqual(merged["carplay-headunit"], 2)
        XCTAssertEqual(merged.compare(to: phoneBranch), .after)
        XCTAssertEqual(merged.compare(to: headUnitBranch), .after)
    }

    func testEnvelopeIntegrityChecksumDetectsTampering() throws {
        let original = SyncEnvelope(
            origin: .headUnit,
            clock: VectorClock(counters: ["carplay-headunit": 1]),
            payload: "Destination: Istanbul Airport"
        )
        XCTAssertTrue(original.hasValidIntegrity)

        let jsonData = try JSONEncoder().encode(original)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        json["payload"] = "Destination: Tampered"
        let tamperedData = try JSONSerialization.data(withJSONObject: json)
        let tampered = try JSONDecoder().decode(SyncEnvelope<String>.self, from: tamperedData)

        XCTAssertFalse(tampered.hasValidIntegrity)
    }
}
