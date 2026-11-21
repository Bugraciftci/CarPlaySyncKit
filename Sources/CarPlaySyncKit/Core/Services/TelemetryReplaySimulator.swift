import Foundation

/// Synchronized navigation and cockpit state shared between iPhone and CarPlay head-unit.
public struct NavigationRouteState: Equatable, Codable, Sendable {
    public let activeDestination: String
    public let remainingDistanceKm: Double
    public let etaMinutes: Int
    public let nextManeuverInstruction: String
    public let mediaTrackTitle: String
    public let hazardAlertActive: Bool

    public init(
        activeDestination: String,
        remainingDistanceKm: Double,
        etaMinutes: Int,
        nextManeuverInstruction: String,
        mediaTrackTitle: String = "Spatial Audio · Telemetry Stream",
        hazardAlertActive: Bool = false
    ) {
        self.activeDestination = activeDestination
        self.remainingDistanceKm = max(0, remainingDistanceKm)
        self.etaMinutes = max(0, etaMinutes)
        self.nextManeuverInstruction = nextManeuverInstruction
        self.mediaTrackTitle = mediaTrackTitle
        self.hazardAlertActive = hazardAlertActive
    }

    public static let initial = NavigationRouteState(
        activeDestination: "Istanbul Airport (IST) · Terminal 1",
        remainingDistanceKm: 34.5,
        etaMinutes: 28,
        nextManeuverInstruction: "Keep left onto O-7 Northbound",
        mediaTrackTitle: "Synthwave Drive · Night Telemetry",
        hazardAlertActive: false
    )
}

/// Deterministic drive-cycle profile for verifying CarPlay safety lockouts and offline vector-clock replay.
public enum DriveScenarioProfile: String, CaseIterable, Codable, Identifiable, Sendable {
    case parkedPreflight = "Parked Preflight (0 km/h)"
    case urbanStopAndGo = "Urban Stop & Go (38 km/h)"
    case highwayCruiseLockout = "Highway Cruise (118 km/h)"
    case tunnelNetworkPartition = "Eurasia Tunnel Partition (76 km/h · Offline)"

    public var id: String { rawValue }
}

/// Deterministic telemetry generator producing vehicle motion, link quality, and candidate POIs for CarPlay HUD testing.
public struct TelemetryReplaySimulator: Sendable {
    public init() {}

    public func telemetry(for scenario: DriveScenarioProfile, timestamp: Date = Date()) -> VehicleTelemetry {
        switch scenario {
        case .parkedPreflight:
            return VehicleTelemetry(
                speedKmh: 0.0,
                headingDegrees: 42.0,
                coordinate: GeoCoordinate(latitude: 41.0422, longitude: 29.0083),
                energyLevelPercent: 94.0,
                linkQuality: .optimal,
                timestamp: timestamp
            )
        case .urbanStopAndGo:
            return VehicleTelemetry(
                speedKmh: 38.0,
                headingDegrees: 115.0,
                coordinate: GeoCoordinate(latitude: 41.0611, longitude: 28.9872),
                energyLevelPercent: 86.0,
                linkQuality: .optimal,
                timestamp: timestamp
            )
        case .highwayCruiseLockout:
            return VehicleTelemetry(
                speedKmh: 118.0,
                headingDegrees: 310.0,
                coordinate: GeoCoordinate(latitude: 41.1824, longitude: 28.7941),
                energyLevelPercent: 74.0,
                linkQuality: .optimal,
                timestamp: timestamp
            )
        case .tunnelNetworkPartition:
            return VehicleTelemetry(
                speedKmh: 76.0,
                headingDegrees: 265.0,
                coordinate: GeoCoordinate(latitude: 41.0018, longitude: 28.9899),
                energyLevelPercent: 69.0,
                linkQuality: .offline,
                timestamp: timestamp
            )
        }
    }

    public func defaultCandidateActionItems() -> [CarPlayActionItem] {
        [
            CarPlayActionItem(id: "sos-hazard", title: "Report Road Hazard / SOS", subtitle: "Safety-Critical Priority", symbolName: "exclamationmark.triangle.fill", isSafetyCritical: true),
            CarPlayActionItem(id: "ev-fast-charge", title: "DC Supercharger · 350 kW", subtitle: "1.4 km ahead · 6 stalls free", symbolName: "bolt.car.fill", isSafetyCritical: true),
            CarPlayActionItem(id: "alt-route-1", title: "Reroute via Northern Marmara", subtitle: "Saves 7 min · Toll road", symbolName: "arrow.triangle.branch", isSafetyCritical: false),
            CarPlayActionItem(id: "poi-coffee", title: "Artisan Espresso Drive-Thru", subtitle: "Exit 4B · +3 min detour", symbolName: "cup.and.saucer.fill", isSafetyCritical: false),
            CarPlayActionItem(id: "poi-parking", title: "Smart Garage P2 (Covered)", subtitle: "240 spaces available", symbolName: "parkingsign.circle.fill", isSafetyCritical: false),
            CarPlayActionItem(id: "poi-service", title: "Authorized Service Center", subtitle: "Tire pressure & diagnostics", symbolName: "wrench.and.screwdriver.fill", isSafetyCritical: false),
            CarPlayActionItem(id: "poi-rest", title: "Highway Rest Area & Lounge", subtitle: "8.2 km ahead", symbolName: "bed.double.fill", isSafetyCritical: false),
            CarPlayActionItem(id: "poi-weather", title: "Crosswind Radar Advisory", subtitle: "42 kt gusts on bridge", symbolName: "wind", isSafetyCritical: false)
        ]
    }
}
