import SwiftUI

/// Horizontally scrollable row of 13 Binance interval buttons.
///
/// Each button is a first-class tvOS focusable element.  The active interval
/// receives a bright accent background; inactive buttons have a muted fill.
/// `.focusSection()` keeps Siri Remote focus confined to this row until the
/// user navigates vertically out of it.
///
/// **Usage:**
/// ```swift
/// TimeframeSelectorView(
///     activeInterval: $viewModel.currentInterval,
///     onSelect: { viewModel.switchInterval($0) }
/// )
/// ```
struct TimeframeSelectorView: View {

    // MARK: - Constants

    /// All 13 Binance kline intervals in display order.
    static let intervals: [String] = [
        "1m", "3m", "5m", "15m", "30m",
        "1h", "2h", "4h", "6h", "12h",
        "1d", "3d", "1w"
    ]

    // MARK: - Inputs

    /// The currently selected interval (two-way binding to `viewModel.currentInterval`).
    @Binding var activeInterval: String

    /// Called when the user presses a timeframe button.
    var onSelect: (String) -> Void

    // MARK: - Focus state

    /// Tracks which interval button currently holds Siri Remote focus.
    @FocusState private var focusedInterval: String?

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.intervals, id: \.self) { interval in
                    intervalButton(interval)
                }
            }
            .padding(.horizontal, 8)
        }
        .focusSection()
    }

    // MARK: - Private: button factory

    @ViewBuilder
    private func intervalButton(_ interval: String) -> some View {
        let isActive = interval == activeInterval

        Button {
            onSelect(interval)
        } label: {
            Text(interval)
                .font(AppTheme.bodyFont)           // .title3 — legible at 10 ft
                .foregroundStyle(isActive ? .black : AppTheme.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 80, minHeight: 80) // tvOS minimum touch target
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                        .fill(isActive ? AppTheme.candleUp : Color(white: 0.18))
                )
        }
        .buttonStyle(.plain)
        .focused($focusedInterval, equals: interval)
        // Scale up when focused (Siri Remote hover) — 200 ms per tvOS guidelines
        .scaleEffect(focusedInterval == interval ? 1.12 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: focusedInterval == interval)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var active = "1h"

    TimeframeSelectorView(activeInterval: $active) { interval in
        active = interval
    }
    .frame(width: 1280, height: 120)
    .background(AppTheme.background)
}
