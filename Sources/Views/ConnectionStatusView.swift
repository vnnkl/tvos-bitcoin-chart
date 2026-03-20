import SwiftUI

/// Shows a colored status dot and text label for the current WebSocket `ConnectionState`.
///
/// Dot colors:
/// - `.connected`    → `AppTheme.stateConnected`    (green)
/// - `.connecting`   → `AppTheme.stateConnecting`   (yellow)
/// - `.reconnecting` → `AppTheme.stateReconnecting` (orange)
/// - `.disconnected` → `AppTheme.stateDisconnected` (red)
///
/// Text size is `.title3` — the tvOS minimum for body text at 10 ft viewing distance.
struct ConnectionStatusView: View {

    let state: ConnectionState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 14, height: 14)
                .shadow(color: dotColor.opacity(0.8), radius: 4)   // soft glow

            Text(stateLabel)
                .font(AppTheme.bodyFont)            // .title3 — tvOS minimum
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Private

    private var dotColor: Color {
        switch state {
        case .connected:    AppTheme.stateConnected
        case .connecting:   AppTheme.stateConnecting
        case .reconnecting: AppTheme.stateReconnecting
        case .disconnected: AppTheme.stateDisconnected
        }
    }

    private var stateLabel: String {
        switch state {
        case .connected:    "Connected"
        case .connecting:   "Connecting…"
        case .reconnecting: "Reconnecting…"
        case .disconnected: "Disconnected"
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ConnectionStatusView(state: .connected)
        ConnectionStatusView(state: .connecting)
        ConnectionStatusView(state: .reconnecting)
        ConnectionStatusView(state: .disconnected)
    }
    .padding(AppTheme.edgePadding)
    .background(AppTheme.background)
}
