import Foundation

/// Delivery priority lane inside the bounded offline command queue.
public enum CommandPriority: Int, Comparable, Codable, Sendable {
    case telemetry = 0
    case navigation = 1
    case safetyCritical = 2

    public static func < (lhs: CommandPriority, rhs: CommandPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Queued outbound synchronization command with retry backoff tracking.
public struct QueuedSyncCommand<Payload: Equatable & Codable & Sendable>: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let priority: CommandPriority
    public let envelope: SyncEnvelope<Payload>
    public let attempts: Int
    public let nextRetryAt: Date

    public init(
        id: UUID = UUID(),
        priority: CommandPriority,
        envelope: SyncEnvelope<Payload>,
        attempts: Int = 0,
        nextRetryAt: Date = .distantPast
    ) {
        self.id = id
        self.priority = priority
        self.envelope = envelope
        self.attempts = attempts
        self.nextRetryAt = nextRetryAt
    }
}

/// Backpressure and retry telemetry emitted by OfflineCommandQueue.
public struct QueueDiagnostics: Equatable, Sendable {
    public let currentDepth: Int
    public let capacity: Int
    public let droppedCount: Int
    public let replayedCount: Int
}

/// Bounded actor-isolated priority ring buffer buffering outbound updates during tunnel/dead-zone disconnects.
public actor OfflineCommandQueue<Payload: Equatable & Codable & Sendable> {
    private let capacity: Int
    private let baseBackoffSeconds: TimeInterval
    private let maxBackoffSeconds: TimeInterval
    private let maxAttempts: Int

    private var buffer: [QueuedSyncCommand<Payload>] = []
    private var droppedCount: Int = 0
    private var replayedCount: Int = 0

    public init(
        capacity: Int = 64,
        baseBackoffSeconds: TimeInterval = 0.5,
        maxBackoffSeconds: TimeInterval = 30.0,
        maxAttempts: Int = 5
    ) {
        self.capacity = max(1, capacity)
        self.baseBackoffSeconds = baseBackoffSeconds
        self.maxBackoffSeconds = maxBackoffSeconds
        self.maxAttempts = max(1, maxAttempts)
    }

    /// Enqueues a command, evicting the oldest lowest-priority entry when full.
    @discardableResult
    public func enqueue(
        _ envelope: SyncEnvelope<Payload>,
        priority: CommandPriority = .navigation
    ) -> Bool {
        if buffer.count >= capacity {
            guard let victimIndex = evictionCandidateIndex(for: priority) else {
                droppedCount += 1
                return false
            }
            buffer.remove(at: victimIndex)
            droppedCount += 1
        }

        let command = QueuedSyncCommand(priority: priority, envelope: envelope)
        buffer.append(command)
        return true
    }

    /// Dequeues the highest-priority ready command whose retry window has elapsed.
    public func dequeueNextReady(now: Date = Date()) -> QueuedSyncCommand<Payload>? {
        let readyIndices = buffer.indices.filter { buffer[$0].nextRetryAt <= now }
        guard let bestIndex = readyIndices.max(by: { lhs, rhs in
            if buffer[lhs].priority != buffer[rhs].priority {
                return buffer[lhs].priority < buffer[rhs].priority
            }
            return lhs > rhs
        }) else {
            return nil
        }
        return buffer.remove(at: bestIndex)
    }

    /// Re-schedules a failed command with exponential backoff or drops it once maxAttempts is exceeded.
    @discardableResult
    public func requeueAfterFailure(_ command: QueuedSyncCommand<Payload>, now: Date = Date()) -> Bool {
        let nextAttempts = command.attempts + 1
        guard nextAttempts < maxAttempts else {
            droppedCount += 1
            return false
        }

        let delay = min(baseBackoffSeconds * pow(2.0, Double(command.attempts)), maxBackoffSeconds)
        let retryCommand = QueuedSyncCommand(
            id: command.id,
            priority: command.priority,
            envelope: command.envelope,
            attempts: nextAttempts,
            nextRetryAt: now.addingTimeInterval(delay)
        )

        if buffer.count >= capacity {
            guard let victim = evictionCandidateIndex(for: retryCommand.priority) else {
                droppedCount += 1
                return false
            }
            buffer.remove(at: victim)
            droppedCount += 1
        }

        buffer.append(retryCommand)
        return true
    }

    public func markReplayed() {
        replayedCount += 1
    }

    public func diagnostics() -> QueueDiagnostics {
        QueueDiagnostics(
            currentDepth: buffer.count,
            capacity: capacity,
            droppedCount: droppedCount,
            replayedCount: replayedCount
        )
    }

    private func evictionCandidateIndex(for incomingPriority: CommandPriority) -> Int? {
        guard let minPriority = buffer.map(\.priority).min() else { return nil }
        guard minPriority <= incomingPriority else { return nil }
        return buffer.firstIndex(where: { $0.priority == minPriority })
    }
}
