import SwiftUI

/// Renders OHLC candlesticks on a SwiftUI `Canvas`.
///
/// **Coordinate system:** Canvas origin is top-left; price axis runs bottom-to-top,
/// so high prices map to low Y values. The helper `priceY(_:in:min:range:)` performs
/// the inversion plus 5 % vertical padding to keep candles away from edges.
///
/// **Sizing:** Candle width and inter-candle spacing are computed from `klines.count`
/// and the available canvas width, respecting `AppTheme.candleMinWidth`.
struct CandlestickChartView: View {

    let klines: [Kline]

    var body: some View {
        Canvas { context, size in
            guard !klines.isEmpty else { return }

            let layout = CandleLayout(count: klines.count, width: size.width)
            let (minPrice, priceRange) = priceExtents(klines)

            for (index, kline) in klines.enumerated() {
                let centerX = layout.centerX(for: index)
                let bodyLeft = centerX - layout.bodyWidth / 2

                // --- Y coordinates (inverted: high price → low Y) ---
                let openY  = priceY(kline.open,  in: size.height, min: minPrice, range: priceRange)
                let closeY = priceY(kline.close, in: size.height, min: minPrice, range: priceRange)
                let highY  = priceY(kline.high,  in: size.height, min: minPrice, range: priceRange)
                let lowY   = priceY(kline.low,   in: size.height, min: minPrice, range: priceRange)

                let color: Color
                if kline.close >= kline.open {
                    color = AppTheme.candleUp
                } else {
                    color = AppTheme.candleDown
                }

                // --- Wick (high → low) ---
                var wickPath = Path()
                wickPath.move(to:   CGPoint(x: centerX, y: highY))
                wickPath.addLine(to: CGPoint(x: centerX, y: lowY))
                context.stroke(wickPath, with: .color(color), lineWidth: 1.5)

                // --- Body (open → close) ---
                let bodyTop    = min(openY, closeY)
                let bodyHeight = max(abs(closeY - openY), 1.5)   // ≥ 1.5 pt for doji
                let bodyRect   = CGRect(
                    x: bodyLeft,
                    y: bodyTop,
                    width: layout.bodyWidth,
                    height: bodyHeight
                )
                context.fill(Path(bodyRect), with: .color(color))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }
}

// MARK: - Private helpers

private extension CandlestickChartView {

    /// Maps a price value to a Y coordinate in the canvas.
    /// `min` and `range` come from `priceExtents` (already padded).
    func priceY(_ price: Decimal, in height: CGFloat, min: CGFloat, range: CGFloat) -> CGFloat {
        let p = CGFloat(NSDecimalNumber(decimal: price).doubleValue)
        return height - ((p - min) / range) * height
    }
}

/// Finds the minimum low and price range across all klines, with 5 % padding.
///
/// This is a free function rather than a method so both `CandlestickChartView` and
/// `ChartContainerView` can call it to derive the same padded price extents,
/// ensuring the heatmap and candlestick Y-axes are identical.
func priceExtents(_ klines: [Kline]) -> (min: CGFloat, range: CGFloat) {
    let lows   = klines.map { NSDecimalNumber(decimal: $0.low).doubleValue }
    let highs  = klines.map { NSDecimalNumber(decimal: $0.high).doubleValue }
    let rawMin = lows.min()  ?? 0
    let rawMax = highs.max() ?? 1
    let pad    = (rawMax - rawMin) * 0.05
    let lo     = rawMin - pad
    let hi     = rawMax + pad
    return (CGFloat(lo), CGFloat(max(hi - lo, 1)))
}

// MARK: - Layout helper

/// Encapsulates candle width, body width, and center-X calculation so the same
/// geometry can be shared with `VolumeBarView`.
struct CandleLayout {
    let slotWidth: CGFloat   // total width per candle slot (body + spacing)
    let bodyWidth: CGFloat   // body width (slotWidth * 0.8)

    init(count: Int, width: CGFloat) {
        let n = max(count, 1)
        slotWidth = width / CGFloat(n)
        bodyWidth = max(slotWidth * 0.8, AppTheme.candleMinWidth)
    }

    /// X coordinate of the center of the candle at `index`.
    func centerX(for index: Int) -> CGFloat {
        CGFloat(index) * slotWidth + slotWidth / 2
    }
}
