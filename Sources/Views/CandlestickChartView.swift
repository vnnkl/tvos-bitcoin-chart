import SwiftUI

/// Renders OHLC candlesticks on a SwiftUI `Canvas`.
///
/// **Coordinate system:** Canvas origin is top-left; price axis runs bottom-to-top,
/// so high prices map to low Y values. `PriceScale` performs the inversion plus
/// 5 % vertical padding to keep candles away from edges.
///
/// **Sizing:** Candle width and inter-candle spacing are computed from `klines.count`
/// and the available canvas width, respecting `AppTheme.candleMinWidth`.
struct CandlestickChartView: View {

    let klines: [Kline]

    var body: some View {
        Canvas { context, size in
            guard !klines.isEmpty else { return }

            let layout = CandleLayout(count: klines.count, width: size.width)
            let scale = PriceScale(klines: klines)

            for (index, kline) in klines.enumerated() {
                let centerX = layout.centerX(for: index)
                let bodyLeft = centerX - layout.bodyWidth / 2

                // --- Y coordinates (inverted: high price → low Y) ---
                let openY  = scale.y(kline.open,  in: size.height)
                let closeY = scale.y(kline.close, in: size.height)
                let highY  = scale.y(kline.high,  in: size.height)
                let lowY   = scale.y(kline.low,   in: size.height)

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
