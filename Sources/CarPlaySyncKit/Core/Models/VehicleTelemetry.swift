import Foundation

/// WGS-84 geographic coordinate value type.
public struct GeoCoordinate: Equatable, Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Real-time vehicle telemetry packet driving CarPlay safety and sync behavior.
public struct VehicleTelemetry: Equatable, Codable, Sendable {
    public enum MotionState: String, Codable, Sendable, Equatable {
        case parked
        case urbanLowSpeed
        case highway
    }

    public enum LinkQuality: String, Codable, Sendable, Equatable {
        case offline
        case degraded
        case optimal
    }

    public let speedKmh: Double
    public let headingDegrees: Double
    public let coordinate: GeoCoordinate
    public let energyLevelPercent: Double
    public let linkQuality: LinkQuality
    public let timestamp: Date

    public init(
        speedKmh: Double,
        headingDegrees: Double = 0,
        coordinate: GeoCoordinate = GeoCoordinate(latitude: 41.0082, longitude: 28.9784),
        energyLevelPercent: Double = 100.0,
        linkQuality: LinkQuality = .optimal,
        timestamp: Date = Date()
    ) {
        self.speedKmh = max(0, speedKmh)
        self.headingDegrees = headingDegrees.truncatingRemainder(dividingBy: 360)
        self.coordinate = coordinate
        self.energyLevelPercent = min(max(energyLevelPercent, 0), 100)
        self.linkQuality = linkQuality
        self.timestamp = timestamp
    }

    public var motionState: MotionState {
        switch speedKmh {
        case ..<2.0:
            return .parked
        case 2.0..<65.0:
            return .urbanLowSpeed
        default:
            return .highway
        }
    }
}
