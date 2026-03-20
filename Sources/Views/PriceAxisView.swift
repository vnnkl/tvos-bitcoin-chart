import SwiftUI

/// Vertical price axis rendered on the right edge of the chart.
///
/// Renders short horizontal tick marks on the left edge plus formatted price
/// labels for each tick. Uses the same `priceMin` / `priceRange` values
/// produced by `priceExtents()` so tick Y-positions are pixel-perfect with
/// the candlestick / line chart that shares the same geometry.
///
/// **Tick snapping:** Iterates through a predefined set of "nice" intervals
/// and picks the smallest one that yields 4–8 ticks within the visible price
/// range. This keeps the axis readable at BTC price scales ($10 k – $120 k)
/// without hardcoding anything.
///
/// **Inspectable state:** Pass `priceMin` and `priceRange` from the same
/// `priceExtents(klines)` call that drives the chart — any mismatch between
/// the axis labels and candlestick positions will be immediately visible on
/// screen.
struct PriceAxisView: View {

    /// Padded minimum price — must match `priceExtents()` output.
    let priceMin: CGFloat
    /// Padded price range — must match `priceExtents()` output.
    let priceRange: CGFloat

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let ticks = computeTicks(height: size.height)

            ZStack(alignment: .topLeading) {
                // Canvas: short tick lines at the left edge of the axis panel.
                Canvas { ctx, canvasSize in
                    let tickColor = GraphicsContext.Shading.color(AppTheme.axisLabelColor)
                    for price in ticks {
                        let y = priceYCoord(price, in: canvasSize.height)
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: 6, y: y))
                        ctx.stroke(path, with: tickColor, lineWidth: 1)
                    }
                }
                .frame(width: size.width, height: size.height)

                // SwiftUI Text labels — Canvas cannot render rich text.
                ForEach(ticks, id: \.self) { price in
                    let y = priceYCoord(price, in: size.height)
                    Text(Self.formatPrice(price))
                        .font(AppTheme.axisFont)
                        .foregroundStyle(AppTheme.axisLabelColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: size.width - 10, alignment: .leading)
                        .position(x: (size.width - 10) / 2 + 10, y: y)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tick computation

    /// "Nice" intervals appropriate for BTC price scales (thousands – tens of thousands).
    private static let niceIntervals: [CGFloat] = [
        10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, 10_000
    ]

    /// Returns tick price values that fall inside the visible price range.
    private func computeTicks(height: CGFloat) -> [CGFloat] {
        guard priceRange > 0 else { return [] }

        let actualMin = priceMin
        let actualMax = priceMin + priceRange

        // Pick smallest interval yielding 4–8 ticks.
        var interval = Self.niceIntervals.last!
        for candidate in Self.niceIntervals {
            let count = Int(priceRange / candidate)
            if count >= 4 && count <= 8 {
                interval = candidate
                break
            }
        }

        // Generate ticks starting from the first multiple of interval >= actualMin.
        var ticks: [CGFloat] = []
        let firstTick = ceil(actualMin / interval) * interval
        var price = firstTick
        while price <= actualMax {
            ticks.append(price)
            price += interval
        }
        return ticks
    }

    // MARK: - Geometry helper

    /// Maps a price value to a Y coordinate using the same formula as all chart views.
    private func priceYCoord(_ price: CGFloat, in height: CGFloat) -> CGFloat {
        guard priceRange > 0 else { return height / 2 }
        return height - ((price - priceMin) / priceRange) * height
    }

    // MARK: - Formatting

    private static let priceFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        return f
    }()

    private static func formatPrice(_ price: CGFloat) -> String {
        Self.priceFormatter.string(from: NSNumber(value: Double(price))) ?? "\(Int(price))"
    }
}
