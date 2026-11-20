import Foundation

/// Transport abstraction connecting the iPhone host app and CarPlay head-unit display.
public protocol SyncTransportProtocol<Payload>: Sendable {
    associatedtype Payload: Equatable & Codable & Sendable
    func send(_ envelope: SyncEnvelope<Payload>) async throws
}

/// Resolution verdict emitted whenever a remote envelope is applied to the sync engine.
public enum SyncApplyOutcome: String, Equatable, Sendable {
    case appliedNewer
    case ignoredStale
    case resolvedConcurrentRemoteWon
    case resolvedConcurrentLocalWon
    case rejectedCorruptedChecksum
}

/// Snapshot emitted over AsyncStream whenever synchronized state updates.
public struct SyncStateSnapshot<Payload: Equatable & Codable & Sendable>: Equatable, Sendable {
    public let state: Payload
    public let clock: VectorClock
    public let lastOrigin: SyncNodeID
    public let conflictCount: Int
}

/// Actor coordinating real-time bidirectional iPhone <-> CarPlay state synchronization with vector clocks & offline replay.
public actor StateSyncEngine<Payload: Equatable & Codable & Sendable> {
    public let localNode: SyncNodeID

    private var currentState: Payload
    private var localClock: VectorClock
    private var lastOrigin: SyncNodeID
    private var conflictCount: Int = 0
    private var isLinkOnline: Bool = true

    private let offlineQueue: OfflineCommandQueue<Payload>
    private var continuations: [UUID: AsyncStream<SyncStateSnapshot<Payload>>.Continuation] = [:]

    public init(
        localNode: SyncNodeID,
        initialState: Payload,
        queueCapacity: Int = 64
    ) {
        self.localNode = localNode
        self.currentState = initialState
        self.localClock = VectorClock()
        self.lastOrigin = localNode
        self.offlineQueue = OfflineCommandQueue<Payload>(capacity: queueCapacity)
    }

    public func currentSnapshot() -> SyncStateSnapshot<Payload> {
        SyncStateSnapshot(
            state: currentState,
            clock: localClock,
            lastOrigin: lastOrigin,
            conflictCount: conflictCount
        )
    }

    public func stateStream() -> AsyncStream<SyncStateSnapshot<Payload>> {
        let id = UUID()
        let initial = currentSnapshot()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(initial)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    public func setLinkOnline(_ online: Bool) {
        isLinkOnline = online
    }

    /// Commits a local mutation, increments the vector clock, and transmits or buffers into the offline ring buffer.
    @discardableResult
    public func mutateLocal(
        _ newState: Payload,
        priority: CommandPriority = .navigation,
        transport: (any SyncTransportProtocol<Payload>)? = nil
    ) async -> SyncEnvelope<Payload> {
        localClock = localClock.incrementing(nodeID: localNode.rawValue)
        currentState = newState
        lastOrigin = localNode

        let envelope = SyncEnvelope(
            origin: localNode,
            clock: localClock,
            payload: newState
        )

        broadcastSnapshot()

        if let transport {
            if isLinkOnline {
                do {
                    try await transport.send(envelope)
                } catch {
                    await offlineQueue.enqueue(envelope, priority: priority)
                }
            } else {
                await offlineQueue.enqueue(envelope, priority: priority)
            }
        }

        return envelope
    }

    /// Applies an incoming envelope from the peer node using vector-clock causal ordering + deterministic tie-breaking.
    @discardableResult
    public func applyRemote(_ envelope: SyncEnvelope<Payload>) -> SyncApplyOutcome {
        guard envelope.hasValidIntegrity else {
            return .rejectedCorruptedChecksum
        }

        let relation = envelope.clock.compare(to: localClock)
        switch relation {
        case .after:
            localClock = localClock.merged(with: envelope.clock)
            currentState = envelope.payload
            lastOrigin = envelope.origin
            broadcastSnapshot()
            return .appliedNewer

        case .before, .equal:
            return .ignoredStale

        case .concurrent:
            conflictCount += 1
            localClock = localClock.merged(with: envelope.clock)
            if envelope.origin > lastOrigin {
                currentState = envelope.payload
                lastOrigin = envelope.origin
                broadcastSnapshot()
                return .resolvedConcurrentRemoteWon
            } else {
                broadcastSnapshot()
                return .resolvedConcurrentLocalWon
            }
        }
    }

    /// Flushes queued offline envelopes in priority order once link connectivity is restored.
    @discardableResult
    public func flushOfflineQueue(
        using transport: any SyncTransportProtocol<Payload>,
        now: Date = Date()
    ) async -> Int {
        guard isLinkOnline else { return 0 }
        var delivered = 0

        while let command = await offlineQueue.dequeueNextReady(now: now) {
            do {
                try await transport.send(command.envelope)
                await offlineQueue.markReplayed()
                delivered += 1
            } catch {
                await offlineQueue.requeueAfterFailure(command, now: now)
                break
            }
        }

        return delivered
    }

    public func queueDiagnostics() async -> QueueDiagnostics {
        await offlineQueue.diagnostics()
    }

    private func broadcastSnapshot() {
        let snapshot = currentSnapshot()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
