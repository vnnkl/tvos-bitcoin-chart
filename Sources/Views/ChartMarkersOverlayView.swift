import SwiftUI

/// Terminal-style price annotations drawn over the candlestick canvas:
///
/// - **Current price**: a yellow → arrow at the last close's Y position,
///   offset left of the last candle with the same gap the extremes labels use
///   (so it never sits on top of the candle body) — visually continuing into
///   the yellow price label drawn by `PriceAxisView` in the axis column.
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
    /// Horizontal gap between a label/arrow and the candle it points at.
    private static let labelGap: CGFloat = 12

    var body: some View {
        let currentClose = klines.last?.close
        let extremes = showsExtremes ? computeExtremes() : []

        Canvas { context, size in
            guard !klines.isEmpty else { return }

            let layout = CandleLayout(count: klines.count, width: size.width)
            let scale = PriceScale(priceMin: priceMin, priceRange: priceRange)

            // ── Current price arrow beside the last candle ─────────────
            // Same glyph, gap, and anchoring as the extremes labels, in
            // terminal-yellow — offset so it never overlaps the candle body.
            if let currentClose {
                let y = scale.y(currentClose, in: size.height)
                let centerX = layout.centerX(for: klines.count - 1)
                let arrow = Text("→")
                    .font(Self.labelFont)
                    .foregroundColor(AppTheme.markerYellow)
                context.draw(arrow, at: CGPoint(x: centerX - Self.labelGap, y: y), anchor: .trailing)
            }

            // ── Visible-range high / low labels ────────────────────────
            for extreme in extremes {
                let centerX = layout.centerX(for: extreme.candleIndex)
                let y = scale.y(extreme.price, in: size.height)
                let onLeft = centerX > size.width / 2

                let text = Text(onLeft ? "\(extreme.label) →" : "← \(extreme.label)")
                    .font(Self.labelFont)
                    .foregroundColor(Self.labelColor)

                if onLeft {
                    context.draw(text, at: CGPoint(x: centerX - Self.labelGap, y: y), anchor: .trailing)
                } else {
                    context.draw(text, at: CGPoint(x: centerX + Self.labelGap, y: y), anchor: .leading)
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
