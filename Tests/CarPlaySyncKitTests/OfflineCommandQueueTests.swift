import XCTest
@testable import CarPlaySyncKit

final class OfflineCommandQueueTests: XCTestCase {
    private func makeEnvelope(_ text: String) -> SyncEnvelope<String> {
        SyncEnvelope(origin: .phone, clock: VectorClock(counters: ["iphone-host": 1]), payload: text)
    }

    func testPriorityDequeueOrderSafetyBeforeNavigationBeforeTelemetry() async {
        let queue = OfflineCommandQueue<String>(capacity: 10)
        await queue.enqueue(makeEnvelope("gps-ping"), priority: .telemetry)
        await queue.enqueue(makeEnvelope("reroute"), priority: .navigation)
        await queue.enqueue(makeEnvelope("collision-alert"), priority: .safetyCritical)

        let first = await queue.dequeueNextReady()
        let second = await queue.dequeueNextReady()
        let third = await queue.dequeueNextReady()

        XCTAssertEqual(first?.envelope.payload, "collision-alert")
        XCTAssertEqual(second?.envelope.payload, "reroute")
        XCTAssertEqual(third?.envelope.payload, "gps-ping")
    }

    func testRingBufferEvictsLowestPriorityWhenFull() async {
        let queue = OfflineCommandQueue<String>(capacity: 2)
        await queue.enqueue(makeEnvelope("tele-1"), priority: .telemetry)
        await queue.enqueue(makeEnvelope("nav-1"), priority: .navigation)

        // Incoming safetyCritical should evict telemetry ("tele-1")
        let accepted = await queue.enqueue(makeEnvelope("sos-1"), priority: .safetyCritical)
        XCTAssertTrue(accepted)

        let diag = await queue.diagnostics()
        XCTAssertEqual(diag.currentDepth, 2)
        XCTAssertEqual(diag.droppedCount, 1)

        let first = await queue.dequeueNextReady()
        let second = await queue.dequeueNextReady()
        XCTAssertEqual(first?.envelope.payload, "sos-1")
        XCTAssertEqual(second?.envelope.payload, "nav-1")
    }

    func testLowPriorityIncomingIsDroppedWhenBufferFullOfHigherPriority() async {
        let queue = OfflineCommandQueue<String>(capacity: 1)
        await queue.enqueue(makeEnvelope("sos-only"), priority: .safetyCritical)

        let accepted = await queue.enqueue(makeEnvelope("tele-drop"), priority: .telemetry)
        XCTAssertFalse(accepted)
        let diag = await queue.diagnostics()
        XCTAssertEqual(diag.droppedCount, 1)
    }

    func testExponentialBackoffAndMaxAttemptDrop() async {
        let queue = OfflineCommandQueue<String>(capacity: 4, baseBackoffSeconds: 2.0, maxBackoffSeconds: 10.0, maxAttempts: 2)
        let t0 = Date(timeIntervalSince1970: 1_000)
        await queue.enqueue(makeEnvelope("retry-me"), priority: .navigation)

        guard let cmd1 = await queue.dequeueNextReady(now: t0) else {
            return XCTFail("Expected command")
        }

        // First failure schedules retry at t0 + 2s
        let requeued1 = await queue.requeueAfterFailure(cmd1, now: t0)
        XCTAssertTrue(requeued1)

        // Not ready at t0 + 1s
        let notYet = await queue.dequeueNextReady(now: t0.addingTimeInterval(1.0))
        XCTAssertNil(notYet)

        // Ready at t0 + 2.5s
        guard let cmd2 = await queue.dequeueNextReady(now: t0.addingTimeInterval(2.5)) else {
            return XCTFail("Expected retried command")
        }
        XCTAssertEqual(cmd2.attempts, 1)

        // Second failure hits maxAttempts=2 and drops
        let requeued2 = await queue.requeueAfterFailure(cmd2, now: t0.addingTimeInterval(2.5))
        XCTAssertFalse(requeued2)
        let diag = await queue.diagnostics()
        XCTAssertEqual(diag.droppedCount, 1)
    }
}
