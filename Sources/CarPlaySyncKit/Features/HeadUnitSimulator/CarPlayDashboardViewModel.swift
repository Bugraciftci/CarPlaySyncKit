import Foundation
import Combine

/// In-memory transport loopback connecting the simulated iPhone host and CarPlay head-unit actors.
public actor LoopbackSyncTransport: SyncTransportProtocol {
    public typealias Payload = NavigationRouteState
    private var deliveredEnvelopes: [SyncEnvelope<NavigationRouteState>] = []
    private var shouldFail: Bool = false

    public init() {}

    public func setFailureMode(_ fail: Bool) {
        shouldFail = fail
    }

    public func send(_ envelope: SyncEnvelope<NavigationRouteState>) async throws {
        if shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        deliveredEnvelopes.append(envelope)
    }

    public func drainDelivered() -> [SyncEnvelope<NavigationRouteState>] {
        let copy = deliveredEnvelopes
        deliveredEnvelopes.removeAll()
        return copy
    }
}

/// @MainActor MVVM ViewModel coordinating the CarPlay Head-Unit HUD and Vector-Clock Diagnostics Console.
@MainActor
public final class CarPlayDashboardViewModel: ObservableObject {
    @Published public private(set) var activeScenario: DriveScenarioProfile = .parkedPreflight
    @Published public private(set) var telemetry: VehicleTelemetry
    @Published public private(set) var projectedList: CarPlayListProjection
    @Published public private(set) var headUnitSnapshot: SyncStateSnapshot<NavigationRouteState>
    @Published public private(set) var phoneSnapshot: SyncStateSnapshot<NavigationRouteState>
    @Published public private(set) var queueDiagnostics: QueueDiagnostics
    @Published public private(set) var lastSyncOutcome: SyncApplyOutcome = .appliedNewer

    private let simulator = TelemetryReplaySimulator()
    private let policy = DriverDistractionPolicy()
    private let phoneEngine: StateSyncEngine<NavigationRouteState>
    private let headUnitEngine: StateSyncEngine<NavigationRouteState>
    private let transport = LoopbackSyncTransport()

    public init() {
        let initialTelemetry = simulator.telemetry(for: .parkedPreflight)
        self.telemetry = initialTelemetry
        self.projectedList = policy.projectList(
            title: "Cockpit Actions",
            items: simulator.defaultCandidateActionItems(),
            telemetry: initialTelemetry
        )
        self.phoneEngine = StateSyncEngine(localNode: .phone, initialState: NavigationRouteState.initial)
        self.headUnitEngine = StateSyncEngine(localNode: .headUnit, initialState: NavigationRouteState.initial)
        let defaultSnap = SyncStateSnapshot<NavigationRouteState>(
            state: NavigationRouteState.initial,
            clock: VectorClock(),
            lastOrigin: .phone,
            conflictCount: 0
        )
        self.headUnitSnapshot = defaultSnap
        self.phoneSnapshot = defaultSnap
        self.queueDiagnostics = QueueDiagnostics(currentDepth: 0, capacity: 64, droppedCount: 0, replayedCount: 0)
    }

    public func applyScenario(_ scenario: DriveScenarioProfile) async {
        activeScenario = scenario
        let nextTelemetry = simulator.telemetry(for: scenario)
        telemetry = nextTelemetry
        projectedList = policy.projectList(
            title: "Cockpit Actions",
            items: simulator.defaultCandidateActionItems(),
            telemetry: nextTelemetry
        )

        let isOnline = nextTelemetry.linkQuality != .offline
        await phoneEngine.setLinkOnline(isOnline)
        await headUnitEngine.setLinkOnline(isOnline)
        await transport.setFailureMode(!isOnline)

        if isOnline {
            _ = await phoneEngine.flushOfflineQueue(using: transport)
            let flushed = await transport.drainDelivered()
            for env in flushed {
                lastSyncOutcome = await headUnitEngine.applyRemote(env)
            }
        }

        await refreshSnapshots()
    }

    /// Simulates a tunnel network partition where both iPhone and CarPlay mutate route state concurrently, then reconnect.
    public func simulateConcurrentConflictAndReconnect() async {
        await applyScenario(.tunnelNetworkPartition)

        let phoneMutation = NavigationRouteState(
            activeDestination: "Sabiha Gökçen (SAW) · Rerouted",
            remainingDistanceKm: 41.2,
            etaMinutes: 33,
            nextManeuverInstruction: "Take Eurasia Tunnel Exit toward D-100",
            mediaTrackTitle: "iPhone Offline Queue Mutation",
            hazardAlertActive: false
        )
        let phoneEnv = await phoneEngine.mutateLocal(phoneMutation, priority: .navigation, transport: transport)

        let headUnitMutation = NavigationRouteState(
            activeDestination: "Emergency EV Charging Bay · Exit 2",
            remainingDistanceKm: 2.1,
            etaMinutes: 4,
            nextManeuverInstruction: "Immediate Right · Safety Override",
            mediaTrackTitle: "CarPlay Head-Unit Direct Override",
            hazardAlertActive: true
        )
        let headUnitEnv = await headUnitEngine.mutateLocal(headUnitMutation, priority: .safetyCritical)

        // Reconnect and exchange concurrent vector-clock envelopes
        await phoneEngine.setLinkOnline(true)
        await headUnitEngine.setLinkOnline(true)
        await transport.setFailureMode(false)

        lastSyncOutcome = await headUnitEngine.applyRemote(phoneEnv)
        _ = await phoneEngine.applyRemote(headUnitEnv)
        _ = await phoneEngine.flushOfflineQueue(using: transport)
        _ = await transport.drainDelivered()

        await refreshSnapshots()
    }

    private func refreshSnapshots() async {
        phoneSnapshot = await phoneEngine.currentSnapshot()
        headUnitSnapshot = await headUnitEngine.currentSnapshot()
        queueDiagnostics = await phoneEngine.queueDiagnostics()
    }
}
