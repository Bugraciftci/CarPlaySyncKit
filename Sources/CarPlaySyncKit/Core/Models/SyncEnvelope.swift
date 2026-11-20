import Foundation

/// Identifies the physical device origin of a state mutation.
public enum SyncNodeID: String, Codable, Sendable, Equatable, Hashable, Comparable {
    case headUnit = "carplay-headunit"
    case phone = "iphone-host"
    case companion = "watch-companion"

    /// Deterministic priority tie-breaker when two edits are causally concurrent.
    /// Head-unit driver actions win ties over background phone updates for immediate cabin responsiveness.
    public var tieBreakPriority: Int {
        switch self {
        case .headUnit: return 3
        case .phone: return 2
        case .companion: return 1
        }
    }

    public static func < (lhs: SyncNodeID, rhs: SyncNodeID) -> Bool {
        lhs.tieBreakPriority < rhs.tieBreakPriority
    }
}

/// Versioned, checksum-verified synchronization envelope transferred between iPhone and CarPlay head-unit.
public struct SyncEnvelope<Payload: Equatable & Codable & Sendable>: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let origin: SyncNodeID
    public let clock: VectorClock
    public let timestamp: Date
    public let payload: Payload
    public let checksum: UInt64

    public init(
        id: UUID = UUID(),
        origin: SyncNodeID,
        clock: VectorClock,
        timestamp: Date = Date(),
        payload: Payload
    ) {
        self.id = id
        self.origin = origin
        self.clock = clock
        self.timestamp = timestamp
        self.payload = payload
        self.checksum = Self.computeChecksum(origin: origin, payload: payload)
    }

    public var hasValidIntegrity: Bool {
        checksum == Self.computeChecksum(origin: origin, payload: payload)
    }

    static func computeChecksum(origin: SyncNodeID, payload: Payload) -> UInt64 {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payloadData = (try? encoder.encode(payload)) ?? Data()
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        for byte in origin.rawValue.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        for byte in payloadData {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return hash
    }
}
