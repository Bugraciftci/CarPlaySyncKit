#if canImport(SwiftUI)
import SwiftUI

/// High-contrast Automotive / Avionics CarPlay Head-Unit HUD simulator view.
public struct CarPlayHeadUnitView: View {
    @ObservedObject private var viewModel: CarPlayDashboardViewModel

    public init(viewModel: CarPlayDashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            telemetryHeaderBar
            scenarioSelectorBar
            navigationCockpitCard
            projectedActionListSection
            SyncDiagnosticsInspectorView(viewModel: viewModel)
        }
        .padding(16)
        .background(Color(red: 0.05, green: 0.06, blue: 0.08))
    }

    private var telemetryHeaderBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CARPLAY HEAD-UNIT HMI")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.cyan)
                Text("\(Int(viewModel.telemetry.speedKmh)) km/h")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("MOTION: \(viewModel.telemetry.motionState.rawValue.uppercased())")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.18)))
                    .foregroundStyle(Color.cyan)

                Text(viewModel.projectedList.isKeyboardSearchAllowed ? "KEYBOARD UNLOCKED" : "SPEED LOCKOUT ACTIVE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(viewModel.projectedList.isKeyboardSearchAllowed ? Color.green : Color.orange)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
        )
    }

    private var scenarioSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DriveScenarioProfile.allCases) { profile in
                    let isSelected = viewModel.activeScenario == profile
                    Button {
                        Task { await viewModel.applyScenario(profile) }
                    } label: {
                        Text(profile.rawValue)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.cyan : Color(red: 0.12, green: 0.14, blue: 0.18))
                            )
                            .foregroundStyle(isSelected ? Color.black : Color.white)
                    }
                }
            }
        }
    }

    private var navigationCockpitCard: some View {
        let route = viewModel.headUnitSnapshot.state
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(route.nextManeuverInstruction, systemImage: "location.north.line.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                Spacer()
                if route.hazardAlertActive {
                    Text("SAFETY OVERRIDE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red))
                        .foregroundStyle(Color.white)
                }
            }

            Text(route.activeDestination)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.75))

            HStack(spacing: 16) {
                Text(String(format: "%.1f km remaining", route.remainingDistanceKm))
                Text("ETA \(route.etaMinutes) min")
                Text(route.mediaTrackTitle)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.cyan)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
        )
    }

    private var projectedActionListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CPListTemplate Projection (\(viewModel.projectedList.visibleItems.count) visible)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white)
                Spacer()
                if viewModel.projectedList.truncatedCount > 0 {
                    Text("\(viewModel.projectedList.truncatedCount) pruned by speed policy")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.orange)
                }
            }

            ForEach(viewModel.projectedList.visibleItems) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.symbolName)
                        .foregroundStyle(item.isSafetyCritical ? Color.orange : Color.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.65))
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.13, green: 0.15, blue: 0.20))
                )
            }
        }
    }
}
#endif
