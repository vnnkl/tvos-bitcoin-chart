import SwiftUI

struct IndicatorOverlayView: View {

    let klines: [Kline]
    var indicatorSettings: IndicatorSettings
    let priceMin: CGFloat
    let priceRange: CGFloat

    var body: some View {
        Canvas { context, size in
            guard !klines.isEmpty else { return }

            let layout = CandleLayout(count: klines.count, width: size.width)

            if indicatorSettings.showEMA21 {
                stroke(
                    context: &context,
                    size: size,
                    layout: layout,
                    series: ema(klines: klines, period: 21),
                    color: AppTheme.indicatorEMA
                )
            }

            if indicatorSettings.showSMA50 {
                stroke(
                    context: &context,
                    size: size,
                    layout: layout,
                    series: sma(klines: klines, period: 50),
                    color: AppTheme.indicatorSMA
                )
            }
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }

    private func stroke(
        context: inout GraphicsContext,
        size: CGSize,
        layout: CandleLayout,
        series: [IndicatorValue],
        color: Color
    ) {
        guard series.count >= 2 else { return }

        let startIndex = klines.count - series.count
        var path = Path()

        for (offset, point) in series.enumerated() {
            let x = layout.centerX(for: startIndex + offset)
            let y = priceY(point.value, in: size.height, min: priceMin, range: priceRange)

            if offset == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(
            path,
            with: .color(color.opacity(0.7)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )
    }
}
