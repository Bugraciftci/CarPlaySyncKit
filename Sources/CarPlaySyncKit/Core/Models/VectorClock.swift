import Foundation

/// Logical causal ordering result between two vector clocks.
public enum CausalRelation: String, Equatable, Sendable {
    case equal
    case before      // lhs causally happened before rhs
    case after       // lhs causally happened after rhs
    case concurrent  // neither clock dominates; conflict resolution required
}

/// Logical vector clock for deterministic causal ordering between iPhone, CarPlay Head-Unit, and Companion nodes.
public struct VectorClock: Equatable, Hashable, Codable, Sendable {
    public private(set) var counters: [String: UInt64]

    public init(counters: [String: UInt64] = [:]) {
        self.counters = counters.filter { $0.value > 0 }
    }

    public subscript(nodeID: String) -> UInt64 {
        counters[nodeID] ?? 0
    }

    public func incrementing(nodeID: String) -> VectorClock {
        var next = counters
        next[nodeID, default: 0] += 1
        return VectorClock(counters: next)
    }

    public func merged(with other: VectorClock) -> VectorClock {
        var combined = counters
        for (node, count) in other.counters {
            combined[node] = max(combined[node] ?? 0, count)
        }
        return VectorClock(counters: combined)
    }

    public func compare(to other: VectorClock) -> CausalRelation {
        let allNodes = Set(counters.keys).union(other.counters.keys)
        var lhsLess = false
        var lhsGreater = false

        for node in allNodes {
            let a = self[node]
            let b = other[node]
            if a < b { lhsLess = true }
            if a > b { lhsGreater = true }
        }

        switch (lhsLess, lhsGreater) {
        case (false, false): return .equal
        case (true, false):  return .before
        case (false, true):  return .after
        case (true, true):   return .concurrent
        }
    }
}
