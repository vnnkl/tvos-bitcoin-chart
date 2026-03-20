import SwiftUI

/// Horizontally scrollable row of 13 Binance interval buttons.
///
/// Compact pill buttons sized for the header bar. Active interval
/// gets a bright green fill; inactive buttons have a subtle dark fill.
struct TimeframeSelectorView: View {

    static let intervals: [String] = [
        "1m", "3m", "5m", "15m", "30m",
        "1h", "2h", "4h", "6h", "12h",
        "1d", "3d", "1w"
    ]

    @Binding var activeInterval: String
    var onSelect: (String) -> Void

    @FocusState private var focusedInterval: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.intervals, id: \.self) { interval in
                    intervalButton(interval)
                }
            }
            .padding(.horizontal, 4)
        }
        .focusSection()
    }

    @ViewBuilder
    private func intervalButton(_ interval: String) -> some View {
        let isActive = interval == activeInterval
        let isFocused = focusedInterval == interval

        Button {
            onSelect(interval)
        } label: {
            Text(interval)
                .font(.system(size: 24, weight: isActive ? .bold : .medium, design: .monospaced))
                .foregroundStyle(isActive ? .black : AppTheme.textPrimary)
                .frame(minWidth: 64, minHeight: 52)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? AppTheme.candleUp : Color(white: 0.12))
                )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focusedInterval, equals: interval)
        .scaleEffect(isFocused ? 1.15 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

#Preview {
    @Previewable @State var active = "1h"

    TimeframeSelectorView(activeInterval: $active) { interval in
        active = interval
    }
    .frame(width: 1280, height: 80)
    .background(AppTheme.background)
}
