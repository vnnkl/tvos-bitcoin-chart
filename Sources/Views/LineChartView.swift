import SwiftUI

/// Renders close prices as a continuous line on a SwiftUI `Canvas`.
///
/// Uses the same coordinate mapping as `CandlestickChartView` (5 % vertical padding,
/// high prices = low Y). The line is stroked in `AppTheme.candleUp`; a translucent fill
/// is drawn below it for depth.
struct LineChartView: View {

    let klines: [Kline]

    var body: some View {
        Canvas { context, size in
            guard klines.count >= 2 else { return }

            let layout = CandleLayout(count: klines.count, width: size.width)
            let scale = PriceScale(klines: klines)

            // Build close-price points
            let points: [CGPoint] = klines.enumerated().map { index, kline in
                let x = layout.centerX(for: index)
                let y = scale.y(kline.close, in: size.height)
                return CGPoint(x: x, y: y)
            }

            // --- Fill below the line ---
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: points[0].x, y: size.height))
            for point in points {
                fillPath.addLine(to: point)
            }
            fillPath.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .color(AppTheme.candleUp.opacity(0.12))
            )

            // --- Stroke the line ---
            var linePath = Path()
            linePath.move(to: points[0])
            for point in points.dropFirst() {
                linePath.addLine(to: point)
            }
            context.stroke(linePath, with: .color(AppTheme.candleUp), lineWidth: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }
}
