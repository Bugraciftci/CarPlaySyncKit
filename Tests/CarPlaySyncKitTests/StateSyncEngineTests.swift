import XCTest
@testable import CarPlaySyncKit

private struct NavigationSessionState: Equatable, Codable, Sendable {
    let destination: String
    let etaMinutes: Int
}

private actor LoopbackTransport: SyncTransportProtocol {
    typealias Payload = NavigationSessionState

    private(set) var sent: [SyncEnvelope<NavigationSessionState>] = []
    var shouldFail: Bool = false

    func setFail(_ fail: Bool) {
        shouldFail = fail
    }

    func send(_ envelope: SyncEnvelope<NavigationSessionState>) async throws {
        if shouldFail {
            throw URLError(.networkConnectionLost)
        }
        sent.append(envelope)
    }

    func allSent() -> [SyncEnvelope<NavigationSessionState>] {
        sent
    }
}

final class StateSyncEngineTests: XCTestCase {
    func testCausalForwardSyncBetweenPhoneAndHeadUnit() async {
        let initial = NavigationSessionState(destination: "Home", etaMinutes: 25)
        let phone = StateSyncEngine(localNode: .phone, initialState: initial)
        let headUnit = StateSyncEngine(localNode: .headUnit, initialState: initial)

        let env = await phone.mutateLocal(NavigationSessionState(destination: "BAU Beşiktaş", etaMinutes: 18))
        let outcome = await headUnit.applyRemote(env)

        XCTAssertEqual(outcome, .appliedNewer)
        let headSnap = await headUnit.currentSnapshot()
        XCTAssertEqual(headSnap.state.destination, "BAU Beşiktaş")
        XCTAssertEqual(headSnap.clock[SyncNodeID.phone.rawValue], 1)

        // Re-applying same envelope is ignored as stale
        let replayOutcome = await headUnit.applyRemote(env)
        XCTAssertEqual(replayOutcome, .ignoredStale)
    }

    func testConcurrentEditsPreferHeadUnitDeterministicallyOnBothNodes() async {
        let initial = NavigationSessionState(destination: "Idle", etaMinutes: 0)
        let phone = StateSyncEngine(localNode: .phone, initialState: initial)
        let headUnit = StateSyncEngine(localNode: .headUnit, initialState: initial)

        // Both nodes mutate offline concurrently
        let phoneEnv = await phone.mutateLocal(NavigationSessionState(destination: "Phone Pick", etaMinutes: 30))
        let headEnv = await headUnit.mutateLocal(NavigationSessionState(destination: "Driver Pick", etaMinutes: 12))

        let phoneOutcome = await phone.applyRemote(headEnv)
        let headOutcome = await headUnit.applyRemote(phoneEnv)

        XCTAssertEqual(phoneOutcome, .resolvedConcurrentRemoteWon)
        XCTAssertEqual(headOutcome, .resolvedConcurrentLocalWon)

        let phoneFinal = await phone.currentSnapshot()
        let headFinal = await headUnit.currentSnapshot()

        // Both nodes converge identically to the driver's head-unit pick!
        XCTAssertEqual(phoneFinal.state, headFinal.state)
        XCTAssertEqual(phoneFinal.state.destination, "Driver Pick")
        XCTAssertEqual(phoneFinal.clock, headFinal.clock)
        XCTAssertEqual(phoneFinal.conflictCount, 1)
    }

    func testOfflineMutationsBufferAndReplayInPriorityOrderOnReconnect() async {
        let initial = NavigationSessionState(destination: "Start", etaMinutes: 10)
        let engine = StateSyncEngine(localNode: .phone, initialState: initial)
        let transport = LoopbackTransport()

        await engine.setLinkOnline(false)
        await engine.mutateLocal(
            NavigationSessionState(destination: "Telemetry Update", etaMinutes: 9),
            priority: .telemetry,
            transport: transport
        )
        await engine.mutateLocal(
            NavigationSessionState(destination: "Emergency Reroute", etaMinutes: 4),
            priority: .safetyCritical,
            transport: transport
        )

        let bufferedSent = await transport.allSent()
        XCTAssertTrue(bufferedSent.isEmpty)

        // Reconnect and flush
        await engine.setLinkOnline(true)
        let replayed = await engine.flushOfflineQueue(using: transport)
        XCTAssertEqual(replayed, 2)

        let sent = await transport.allSent()
        XCTAssertEqual(sent.map(\.payload.destination), ["Emergency Reroute", "Telemetry Update"])

        let diag = await engine.queueDiagnostics()
        XCTAssertEqual(diag.currentDepth, 0)
        XCTAssertEqual(diag.replayedCount, 2)
    }

    func testTransportFailureAutoBuffersIntoOfflineQueue() async {
        let initial = NavigationSessionState(destination: "Start", etaMinutes: 10)
        let engine = StateSyncEngine(localNode: .phone, initialState: initial)
        let transport = LoopbackTransport()
        await transport.setFail(true)

        await engine.mutateLocal(
            NavigationSessionState(destination: "Tunnel Update", etaMinutes: 11),
            priority: .navigation,
            transport: transport
        )

        let diag = await engine.queueDiagnostics()
        XCTAssertEqual(diag.currentDepth, 1)
    }
}
