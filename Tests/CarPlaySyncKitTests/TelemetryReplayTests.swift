import XCTest
@testable import CarPlaySyncKit

final class TelemetryReplayTests: XCTestCase {

    func testDriveScenarioProfilesEnforceExpectedMotionAndLinkStates() {
        let simulator = TelemetryReplaySimulator()

        let parked = simulator.telemetry(for: .parkedPreflight)
        XCTAssertEqual(parked.motionState, .parked)
        XCTAssertEqual(parked.linkQuality, .optimal)

        let highway = simulator.telemetry(for: .highwayCruiseLockout)
        XCTAssertEqual(highway.motionState, .highway)
        XCTAssertGreaterThan(highway.speedKmh, 100)

        let tunnel = simulator.telemetry(for: .tunnelNetworkPartition)
        XCTAssertEqual(tunnel.linkQuality, .offline)
    }

    @MainActor
    func testDashboardViewModelHighwayScenarioPrunesListAndLocksKeyboard() async {
        let vm = CarPlayDashboardViewModel()
        await vm.applyScenario(.highwayCruiseLockout)

        XCTAssertFalse(vm.projectedList.isKeyboardSearchAllowed)
        XCTAssertEqual(vm.projectedList.visibleItems.count, 6)
        XCTAssertEqual(vm.projectedList.truncatedCount, 2)
        XCTAssertTrue(vm.projectedList.visibleItems.first?.isSafetyCritical == true)
    }

    @MainActor
    func testDashboardViewModelResolvesConcurrentTunnelPartitionFavoringHeadUnitSafetyOverride() async {
        let vm = CarPlayDashboardViewModel()
        await vm.simulateConcurrentConflictAndReconnect()

        XCTAssertEqual(vm.headUnitSnapshot.conflictCount, 1)
        XCTAssertEqual(vm.lastSyncOutcome, .resolvedConcurrentLocalWon)
        XCTAssertTrue(vm.headUnitSnapshot.state.hazardAlertActive)
        XCTAssertEqual(vm.headUnitSnapshot.state.lastOriginOrSafetyCheck, true)
    }
}

private extension NavigationRouteState {
    var lastOriginOrSafetyCheck: Bool {
        hazardAlertActive && activeDestination.contains("Emergency EV")
    }
}
