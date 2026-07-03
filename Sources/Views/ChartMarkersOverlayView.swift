import SwiftUI

/// Terminal-style price annotations drawn over the candlestick canvas:
///
/// - **Current price**: a yellow ◀ arrowhead at the chart's right edge, at the
///   last close's Y position — visually continuing into the yellow price label
///   drawn by `PriceAxisView` in the axis column beside it.
/// - **Visible-range extremes**: the highest high and lowest low of the visible
///   klines, labeled beside the candle that set them ("62,660 →" / "← 61,333").
///   The label sits on whichever side of the candle has more room, with the
///   arrow pointing at the wick tip.
///
/// Shares `priceMin` / `priceRange` with the candle canvas so all Y positions
/// are pixel-identical.
@MainActor
struct ChartMarkersOverlayView: View {

    let klines: [Kline]
    let priceMin: CGFloat
    let priceRange: CGFloat
    /// High/low wick labels only make sense on candlesticks — the line chart
    /// plots closes, so wick extremes would point at empty space.
    let showsExtremes: Bool

    /// One extreme annotation, precomputed on the main actor so the Canvas
    /// closure only performs geometry.
    private struct Extreme {
        let label: String
        let price: Decimal
        let candleIndex: Int
    }

    private static let labelFont = Font.system(size: 18, weight: .semibold, design: .monospaced)
    private static let labelColor = Color(white: 0.88)

    var body: some View {
        let currentClose = klines.last?.close
        let extremes = showsExtremes ? computeExtremes() : []

        Canvas { context, size in
            guard !klines.isEmpty else { return }

            let layout = CandleLayout(count: klines.count, width: size.width)
            let scale = PriceScale(priceMin: priceMin, priceRange: priceRange)

            // ── Current price arrowhead at the right edge ──────────────
            if let currentClose {
                let y = scale.y(currentClose, in: size.height)
                var arrow = Path()
                arrow.move(to: CGPoint(x: size.width, y: y - 8))
                arrow.addLine(to: CGPoint(x: size.width, y: y + 8))
                arrow.addLine(to: CGPoint(x: size.width - 11, y: y))
                arrow.closeSubpath()
                context.fill(arrow, with: .color(AppTheme.markerYellow))
            }

            // ── Visible-range high / low labels ────────────────────────
            for extreme in extremes {
                let centerX = layout.centerX(for: extreme.candleIndex)
                let y = scale.y(extreme.price, in: size.height)
                let onLeft = centerX > size.width / 2

                let text = Text(onLeft ? "\(extreme.label) →" : "← \(extreme.label)")
                    .font(Self.labelFont)
                    .foregroundColor(Self.labelColor)

                let gap: CGFloat = 12
                if onLeft {
                    context.draw(text, at: CGPoint(x: centerX - gap, y: y), anchor: .trailing)
                } else {
                    context.draw(text, at: CGPoint(x: centerX + gap, y: y), anchor: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    /// Locates the highest high and lowest low among the visible klines and
    /// formats their labels (main-actor: `AppFormatters` is not Sendable).
    private func computeExtremes() -> [Extreme] {
        var result: [Extreme] = []

        if let (index, kline) = klines.enumerated().max(by: { $0.element.high < $1.element.high }) {
            result.append(Extreme(label: Self.formatPrice(kline.high), price: kline.high, candleIndex: index))
        }
        if let (index, kline) = klines.enumerated().min(by: { $0.element.low < $1.element.low }) {
            result.append(Extreme(label: Self.formatPrice(kline.low), price: kline.low, candleIndex: index))
        }
        return result
    }

    private static func formatPrice(_ price: Decimal) -> String {
        AppFormatters.axisPrice.string(from: price as NSDecimalNumber) ?? "\(price)"
    }
}
