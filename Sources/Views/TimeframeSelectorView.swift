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
    var focusScope: Namespace.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.intervals, id: \.self) { interval in
                    intervalButton(interval)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)   // headroom for the focus scale/glow
        }
        .focusSection()
    }

    @ViewBuilder
    private func intervalButton(_ interval: String) -> some View {
        let isActive = interval == activeInterval

        Group {
            if let focusScope {
                button(for: interval, isActive: isActive)
                    .prefersDefaultFocus(isActive, in: focusScope)
            } else {
                button(for: interval, isActive: isActive)
            }
        }
    }

    private func button(for interval: String, isActive: Bool) -> some View {
        Button {
            onSelect(interval)
        } label: {
            PillLabel(text: interval, isActive: isActive)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

#Preview {
    @Previewable @State var active = "1h"
    @Previewable @Namespace var previewFocusScope

    TimeframeSelectorView(activeInterval: $active, onSelect: { interval in
        active = interval
    }, focusScope: previewFocusScope)
    .frame(width: 1280, height: 80)
    .background(AppTheme.background)
}
