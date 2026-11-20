import Foundation

/// Navigation or in-vehicle list item projected onto Apple CarPlay CPTemplate hierarchies.
public struct CarPlayActionItem: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let symbolName: String
    public let isSafetyCritical: Bool

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        symbolName: String = "location.fill",
        isSafetyCritical: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.isSafetyCritical = isSafetyCritical
    }
}

/// Platform-independent projection of an Apple CarPlay CPListTemplate respecting driver-distraction rules.
public struct CarPlayListProjection: Equatable, Codable, Sendable {
    public let title: String
    public let visibleItems: [CarPlayActionItem]
    public let truncatedCount: Int
    public let isKeyboardSearchAllowed: Bool
    public let appliedMotionState: VehicleTelemetry.MotionState

    public init(
        title: String,
        visibleItems: [CarPlayActionItem],
        truncatedCount: Int,
        isKeyboardSearchAllowed: Bool,
        appliedMotionState: VehicleTelemetry.MotionState
    ) {
        self.title = title
        self.visibleItems = visibleItems
        self.truncatedCount = truncatedCount
        self.isKeyboardSearchAllowed = isKeyboardSearchAllowed
        self.appliedMotionState = appliedMotionState
    }
}
