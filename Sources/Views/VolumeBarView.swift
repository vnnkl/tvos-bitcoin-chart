import SwiftUI

/// Renders a volume histogram below the main chart area.
///
/// X positioning matches `CandlestickChartView` exactly (same `CandleLayout`
/// geometry over the same drawable width — `trailingGutter` reserves the price
/// axis column so bars line up with their candles instead of drifting under
/// the axis).
/// Bar colors mirror candle direction: green (close ≥ open) / red (close < open).
/// Opacity is 0.7 to keep volume visually subordinate to price.
///
/// The current candle's volume is labeled in terminal-yellow inside the gutter,
/// at the top of the last bar ("← 430.7").
struct VolumeBarView: View {

    let klines: [Kline]
    /// Width reserved on the right (the price-axis column). Bars are laid out
    /// over `width - trailingGutter`; the current-volume label lives here.
    var trailingGutter: CGFloat = 0

    var body: some View {
        let currentLabel = klines.last.map { "← \(AppFormatters.compact($0.volume))" }

        Canvas { context, size in
            guard !klines.isEmpty else { return }

            let drawableWidth = max(size.width - trailingGutter, 1)
            let layout = CandleLayout(count: klines.count, width: drawableWidth)

            let volumes = klines.map { NSDecimalNumber(decimal: $0.volume).doubleValue }
            let maxVol  = volumes.max() ?? 1.0
            guard maxVol > 0 else { return }

            var lastBarTop = size.height

            for (index, kline) in klines.enumerated() {
                let vol   = NSDecimalNumber(decimal: kline.volume).doubleValue
                let ratio = CGFloat(vol / maxVol)

                let barHeight = size.height * ratio
                let barLeft   = layout.centerX(for: index) - layout.bodyWidth / 2
                let barRect   = CGRect(
                    x: barLeft,
                    y: size.height - barHeight,
                    width: layout.bodyWidth,
                    height: barHeight
                )

                let color: Color = kline.close >= kline.open
                    ? AppTheme.candleUp
                    : AppTheme.candleDown

                context.fill(Path(barRect), with: .color(color.opacity(0.7)))

                if index == klines.count - 1 {
                    lastBarTop = barRect.minY
                }
            }

            // Current volume in terminal-yellow, in the axis gutter beside
            // the last bar.
            if let currentLabel, trailingGutter > 0 {
                let text = Text(currentLabel)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.markerYellow)
                let y = min(max(lastBarTop, 12), size.height - 12)
                context.draw(text, at: CGPoint(x: drawableWidth + 6, y: y), anchor: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }
}
