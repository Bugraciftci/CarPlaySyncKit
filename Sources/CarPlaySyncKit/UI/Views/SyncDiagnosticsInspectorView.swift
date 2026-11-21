#if canImport(SwiftUI)
import SwiftUI

/// Live causal Vector-Clock & Priority Ring-Buffer diagnostics console for inspecting conflict resolution.
public struct SyncDiagnosticsInspectorView: View {
    @ObservedObject private var viewModel: CarPlayDashboardViewModel

    public init(viewModel: CarPlayDashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("VECTOR-CLOCK & RING-BUFFER TELEMETRY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.green)
                Spacer()
                Text("Verdict: \(viewModel.lastSyncOutcome.rawValue)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Head-Unit Clock")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text("\(viewModel.headUnitSnapshot.clock.counters.description)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Conflicts Resolved: \(viewModel.headUnitSnapshot.conflictCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.orange)
                    Text("Queue Depth: \(viewModel.queueDiagnostics.currentDepth)/\(viewModel.queueDiagnostics.capacity)")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }

            Button {
                Task { await viewModel.simulateConcurrentConflictAndReconnect() }
            } label: {
                Text("Simulate Tunnel Partition & Concurrent Vector-Clock Conflict")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.cyan.opacity(0.2))
                    )
                    .foregroundStyle(Color.cyan)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.09, green: 0.11, blue: 0.15))
        )
    }
}
#endif
