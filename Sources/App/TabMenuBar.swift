import SwiftUI

/// The three top-level destinations of the app.
enum AppTab: String, CaseIterable, Sendable {
    case chart
    case strc
    case settings

    var title: String {
        switch self {
        case .chart:    "Chart"
        case .strc:     "STRC"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .chart:    "chart.bar"
        case .strc:     "building.columns"
        case .settings: "gearshape"
        }
    }
}

/// Custom floating tab bar replacing the system `TabView` bar.
///
/// The system bar cannot be hidden on demand, permanently costing a strip of
/// screen. This bar fades out when focus moves into the content below (the
/// chart then uses the full screen) and fades back in when `ContentView`
/// receives a Menu press. Menu while the bar is focused falls through to the
/// system and exits the app — matching tvOS conventions.
struct TabMenuBar: View {

    let selectedTab: AppTab
    @FocusState.Binding var focusedTab: AppTab?
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(8)
        .background(Capsule().fill(AppTheme.surface))
        .overlay(Capsule().strokeBorder(AppTheme.panelStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = tab == selectedTab

        Button {
            onSelect(tab)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 26, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .black : AppTheme.textPrimary)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Capsule().fill(isSelected ? AppTheme.accent : .clear))
            .focusHighlight(cornerRadius: 28, scale: 1.05)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focusedTab, equals: tab)
    }
}
