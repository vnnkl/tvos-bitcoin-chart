import SwiftUI

/// Compact connection status indicator — colored dot with optional label.
///
/// In the header bar context, shows just the dot + short label.
/// Dot has a subtle glow matching the state color.
struct ConnectionStatusView: View {

    let state: ConnectionState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .shadow(color: dotColor.opacity(0.8), radius: 5)

            Text(stateLabel)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(state == .connected ? dotColor : AppTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Capsule().fill(AppTheme.surface))
        .overlay(Capsule().strokeBorder(dotColor.opacity(0.35), lineWidth: 1))
    }

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
        case .connected:    "Live"
        case .connecting:   "Connecting…"
        case .reconnecting: "Reconnecting…"
        case .disconnected: "Offline"
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
