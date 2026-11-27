import XCTest
@testable import CarPlaySyncKit

private actor FlakyRecordingTransport: SyncTransportProtocol {
    enum TransportError: Error { case linkDown }

    private(set) var sentEnvelopes: [SyncEnvelope<String>] = []
    private var shouldFail = true

    func setShouldFail(_ fail: Bool) {
        shouldFail = fail
    }

    func send(_ envelope: SyncEnvelope<String>) async throws {
        if shouldFail {
            throw TransportError.linkDown
        }
        sentEnvelopes.append(envelope)
    }

    func recordedPayloads() -> [String] {
        sentEnvelopes.map(\.payload)
    }
}

final class StressAndBenchmarkTests: XCTestCase {
    func testConcurrentMutationAndPriorityQueueBackpressure() async {
        let transport = FlakyRecordingTransport()
        let engine = StateSyncEngine<String>(
            localNode: .headUnit,
            initialState: "idle",
            queueCapacity: 16
        )
        await engine.setLinkOnline(false)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                let priority: CommandPriority
                switch i % 10 {
                case 0:
                    priority = .safetyCritical
                case 1, 2, 3:
                    priority = .navigation
                default:
                    priority = .telemetry
                }
                group.addTask {
                    await engine.mutateLocal("state-\(i)", priority: priority, transport: transport)
                }
            }
        }

        let diag = await engine.queueDiagnostics()
        XCTAssertEqual(diag.currentDepth, 16)
        XCTAssertEqual(diag.droppedCount, 84)

        await engine.setLinkOnline(true)
        await transport.setShouldFail(false)

        let delivered = await engine.flushOfflineQueue(using: transport)
        XCTAssertEqual(delivered, 16)

        let postFlushDiag = await engine.queueDiagnostics()
        XCTAssertEqual(postFlushDiag.currentDepth, 0)
        XCTAssertEqual(postFlushDiag.replayedCount, 16)
    }

    func testVectorClockMergeAndEnvelopeIntegrityThroughput() {
        let iterations = 5_000
        let start = CFAbsoluteTimeGetCurrent()

        var clockA = VectorClock(counters: ["carplay-headunit": 1, "iphone-host": 1])
        var clockB = VectorClock(counters: ["iphone-host": 2, "watch-companion": 1])

        for i in 0..<iterations {
            clockA = clockA.incrementing(nodeID: "carplay-headunit")
            clockB = clockB.incrementing(nodeID: "iphone-host")
            _ = clockA.compare(to: clockB)
            let merged = clockA.merged(with: clockB)
            let envelope = SyncEnvelope(origin: .headUnit, clock: merged, payload: "tick-\(i)")
            XCTAssertTrue(envelope.hasValidIntegrity)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(elapsed, 5.0, "5k vector clock merges + FNV-1a envelope checksums took \(elapsed)s")
    }
}
