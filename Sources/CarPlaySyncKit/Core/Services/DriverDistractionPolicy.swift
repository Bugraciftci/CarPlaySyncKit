import Foundation

/// Enforces Apple CarPlay driver-distraction and safety constraints dynamically based on vehicle motion.
public struct DriverDistractionPolicy: Sendable, Equatable {
    public let parkedMaxItems: Int
    public let urbanMaxItems: Int
    public let highwayMaxItems: Int
    public let maxTemplateHierarchyDepth: Int

    public init(
        parkedMaxItems: Int = 24,
        urbanMaxItems: Int = 12,
        highwayMaxItems: Int = 6,
        maxTemplateHierarchyDepth: Int = 5
    ) {
        self.parkedMaxItems = parkedMaxItems
        self.urbanMaxItems = urbanMaxItems
        self.highwayMaxItems = highwayMaxItems
        self.maxTemplateHierarchyDepth = maxTemplateHierarchyDepth
    }

    public func maxItems(for motionState: VehicleTelemetry.MotionState) -> Int {
        switch motionState {
        case .parked: return parkedMaxItems
        case .urbanLowSpeed: return urbanMaxItems
        case .highway: return highwayMaxItems
        }
    }

    public func allowsKeyboardInput(for motionState: VehicleTelemetry.MotionState) -> Bool {
        motionState == .parked
    }

    public func canPushTemplate(currentDepth: Int, motionState: VehicleTelemetry.MotionState) -> Bool {
        let effectiveLimit = motionState == .highway ? min(maxTemplateHierarchyDepth, 3) : maxTemplateHierarchyDepth
        return currentDepth < effectiveLimit
    }

    /// Projects raw items into a CarPlay-safe list, always preserving safety-critical actions first.
    public func projectList(
        title: String,
        items: [CarPlayActionItem],
        telemetry: VehicleTelemetry
    ) -> CarPlayListProjection {
        let state = telemetry.motionState
        let limit = maxItems(for: state)
        let prioritized = items.filter(\.isSafetyCritical) + items.filter { !$0.isSafetyCritical }
        let visible = Array(prioritized.prefix(limit))
        let truncated = max(0, prioritized.count - visible.count)

        return CarPlayListProjection(
            title: title,
            visibleItems: visible,
            truncatedCount: truncated,
            isKeyboardSearchAllowed: allowsKeyboardInput(for: state),
            appliedMotionState: state
        )
    }
}
