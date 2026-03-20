import SwiftUI

/// Horizontal time axis rendered below the chart area.
///
/// Picks ~5–7 evenly-spaced klines and places a timestamp label at each
/// candle's center X position using `CandleLayout.centerX(for:)` — the same
/// geometry used by `CandlestickChartView` — so labels align precisely with
/// candle bodies regardless of zoom level.
///
/// **Format adaptation:**
/// - Intraday intervals (1m … 12h): `HH:mm`
/// - Daily+ intervals (1d, 3d, 1w): `MMM dd`
///
/// **Inspectable state:** The axis automatically re-renders when `klines`
/// or `currentInterval` changes. If labels look wrong, verify that
/// `currentInterval` matches the interval string used by the WebSocket feed
/// (e.g. `"1h"`, `"1d"`).
struct TimeAxisView: View {

    /// Klines in the currently visible window. Must be the same slice
    /// passed to `CandlestickChartView` so X positions align.
    let klines: [Kline]
    /// Active Binance interval string — drives date format selection.
    let currentInterval: String

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let layout = CandleLayout(count: klines.count, width: size.width)
            let indices = pickedIndices()

            ZStack(alignment: .topLeading) {
                // Labels positioned at each candle's center X.
                ForEach(indices, id: \.self) { idx in
                    let x = layout.centerX(for: idx)
                    let label = formatDate(klines[idx].openTime)
                    Text(label)
                        .font(AppTheme.axisFont)
                        .foregroundStyle(AppTheme.axisLabelColor)
                        .lineLimit(1)
                        .fixedSize()
                        .position(x: x, y: size.height / 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Index selection

    /// Returns ~5–7 evenly-spaced indices across the klines array.
    private func pickedIndices() -> [Int] {
        let count = klines.count
        guard count > 1 else { return count == 1 ? [0] : [] }

        let step = max(1, count / 6)
        var result: [Int] = []
        var i = step / 2   // start slightly offset from 0 to avoid left edge crowding
        while i < count {
            result.append(i)
            i += step
        }
        return result
    }

    // MARK: - Date formatting

    /// Intraday interval suffixes that use HH:mm format.
    private static let intradayIntervals: Set<String> = [
        "1m", "3m", "5m", "15m", "30m",
        "1h", "2h", "4h", "6h", "12h"
    ]

    private static let intradayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dailyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        if Self.intradayIntervals.contains(currentInterval) {
            return Self.intradayFormatter.string(from: date)
        } else {
            return Self.dailyFormatter.string(from: date)
        }
    }
}
