# Changelog

All notable changes to `CarPlaySyncKit` are documented in this file.

## [2.0.0] - 2026-11-27

### Added
- Vector-clock causal ordering (`VectorClock`) and deterministic driver-first tie-breaking (`StateSyncEngine`).
- Bounded priority ring-buffer offline queue (`OfflineCommandQueue`) with `.safetyCritical`, `.navigation`, and `.telemetry` lanes plus exponential backoff replay.
- Speed-aware Apple CarPlay driver-distraction safety policy (`DriverDistractionPolicy`).
- SwiftUI Automotive HUD Simulator (`CarPlayHeadUnitView`), diagnostics inspector (`SyncDiagnosticsInspectorView`), and deterministic drive-cycle telemetry replay (`TelemetryReplaySimulator`).
- 100-task concurrency backpressure stress tests and 5k-iteration vector-clock + FNV-1a checksum benchmarks.
- GitHub Actions CI (`macos-15`), Swift DocC static documentation deployment, and `.spi.yml` for Swift Package Index.
