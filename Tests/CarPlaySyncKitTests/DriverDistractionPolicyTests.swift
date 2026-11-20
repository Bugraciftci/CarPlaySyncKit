import XCTest
@testable import CarPlaySyncKit

final class DriverDistractionPolicyTests: XCTestCase {
    private let policy = DriverDistractionPolicy(
        parkedMaxItems: 20,
        urbanMaxItems: 10,
        highwayMaxItems: 4,
        maxTemplateHierarchyDepth: 5
    )

    func testMotionStateThresholdsFromSpeed() {
        XCTAssertEqual(VehicleTelemetry(speedKmh: 0).motionState, .parked)
        XCTAssertEqual(VehicleTelemetry(speedKmh: 42).motionState, .urbanLowSpeed)
        XCTAssertEqual(VehicleTelemetry(speedKmh: 110).motionState, .highway)
    }

    func testHighwaySpeedTruncatesListAndPinsSafetyCriticalItemsFirst() {
        let items = [
            CarPlayActionItem(id: "poi-1", title: "Coffee Shop"),
            CarPlayActionItem(id: "poi-2", title: "Mall"),
            CarPlayActionItem(id: "poi-3", title: "Parking"),
            CarPlayActionItem(id: "poi-4", title: "Gym"),
            CarPlayActionItem(id: "poi-5", title: "Library"),
            CarPlayActionItem(id: "sos-1", title: "Roadside Assistance", isSafetyCritical: true),
            CarPlayActionItem(id: "ev-1", title: "Emergency Charge Stop", isSafetyCritical: true)
        ]

        let highwayTelemetry = VehicleTelemetry(speedKmh: 105)
        let projection = policy.projectList(title: "Nearby", items: items, telemetry: highwayTelemetry)

        XCTAssertEqual(projection.appliedMotionState, .highway)
        XCTAssertEqual(projection.visibleItems.count, 4)
        XCTAssertEqual(projection.truncatedCount, 3)
        XCTAssertFalse(projection.isKeyboardSearchAllowed)
        XCTAssertEqual(projection.visibleItems[0].id, "sos-1")
        XCTAssertEqual(projection.visibleItems[1].id, "ev-1")
    }

    func testParkedModeAllowsKeyboardInputAndFullTemplateDepth() {
        let parked = VehicleTelemetry(speedKmh: 0)
        XCTAssertTrue(policy.allowsKeyboardInput(for: parked.motionState))
        XCTAssertTrue(policy.canPushTemplate(currentDepth: 4, motionState: .parked))
        XCTAssertFalse(policy.canPushTemplate(currentDepth: 3, motionState: .highway))
    }
}
