import SwiftUI

/// Renders a volume histogram below the main chart area.
///
/// X positioning matches `CandlestickChartView` exactly (same `CandleLayout` geometry).
/// Bar colors mirror candle direction: green (close ≥ open) / red (close < open).
/// Opacity is 0.7 to keep volume visually subordinate to price.
struct VolumeBarView: View {

    let klines: [Kline]

    var body: some View {
        Canvas { context, size in
            guard !klines.isEmpty else { return }

            let layout = CandleLayout(count: klines.count, width: size.width)

            let volumes = klines.map { NSDecimalNumber(decimal: $0.volume).doubleValue }
            let maxVol  = volumes.max() ?? 1.0
            guard maxVol > 0 else { return }

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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }
}
