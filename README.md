<div align="center">
  <img src="./assets/banner.svg" width="100%" alt="CarPlaySyncKit Banner" />
</div>

<p align="center">
  <img src="https://img.shields.io/badge/Swift_6.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6" />
  <img src="https://img.shields.io/badge/iOS_17%2B_%7C_CarPlay_%7C_macOS_14%2B-10B981?style=for-the-badge&logo=apple&logoColor=white" alt="Platforms" />
  <img src="https://img.shields.io/badge/Concurrency-Strict_Actors-38BDF8?style=for-the-badge" alt="Actors" />
  <img src="https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge" alt="License" />
</p>

Real-time **Swift 6 bidirectional state synchronization, vector-clock conflict resolution, bounded priority ring-buffer offline queueing, and speed-aware Apple CarPlay driver-distraction safety policy** engine.

## Architecture

```mermaid
flowchart LR
    P["iPhone Host App"] <--> SE["actor StateSyncEngine<br/>VectorClock + Deterministic Tie-Break"]
    SE <--> RB["actor OfflineCommandQueue<br/>Priority Ring Buffer + Exp. Backoff"]
    SE <--> TR["SyncTransportProtocol<br/>Loopback · IPC · WebSocket"]
    TR <--> CP["CarPlay Head-Unit<br/>CPListTemplate Projection"]
    DP["DriverDistractionPolicy<br/>Parked · Urban · Highway Safety Rules"] --> CP
```

## Key Engineering Highlights

- **Vector Clock Causality (`VectorClock.swift`):** Detects `.before`, `.after`, `.equal`, and `.concurrent` mutations across iPhone, CarPlay Head-Unit, and Companion nodes without relying on wall-clock skew.
- **Deterministic Driver-First Conflict Resolution (`StateSyncEngine.swift`):** Resolves concurrent edits reproducibly (prioritizing in-cabin head-unit interactions over background phone sync) and broadcasts snapshots over multi-consumer `AsyncStream`.
- **Priority Ring-Buffer Offline Queue (`OfflineCommandQueue.swift`):** Actor-isolated bounded buffer with `.safetyCritical`, `.navigation`, and `.telemetry` lanes, priority-aware backpressure eviction, and exponential backoff replay on reconnect.
- **Speed-Aware CarPlay Safety Policy (`DriverDistractionPolicy.swift`):** Adapts `CPListTemplate` item depth, template hierarchy limits, and keyboard search lockouts dynamically based on `VehicleTelemetry.motionState` while keeping safety-critical actions pinned first.
- **Payload Integrity Verification (`SyncEnvelope.swift`):** Deterministic 64-bit FNV-1a envelope checksums reject corrupted frames before mutating state.

## Running Tests

```bash
swift test
```

## License

MIT — see [LICENSE](./LICENSE).
