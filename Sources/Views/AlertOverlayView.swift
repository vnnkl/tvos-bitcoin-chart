import SwiftUI

/// Canvas overlay that draws a dashed horizontal line at each enabled alert's price level.
///
/// Follows the exact same overlay pattern as `CrosshairOverlayView`:
/// - Uses `GeometryReader` + `Canvas` so it fills the chart ZStack's bounds.
/// - Applies `.allowsHitTesting(false)` so it never intercepts Siri Remote focus.
/// - Uses the same `priceYCoord` formula as `CrosshairOverlayView` / `CandlestickChartView`.
///
/// **Visual encoding:**
/// - `.above` alerts: yellow (`AppTheme.alertLine`) dashed line — "waiting to cross up"
/// - `.below` alerts: red (`AppTheme.candleDown`) dashed line — "waiting to cross down"
/// - Already-triggered alerts: drawn at half opacity to indicate they have fired.
/// - Price label at the right edge (inset 12 pt) for 10 ft legibility.
///
/// **Inspectable state:**
/// - `alerts` array controls how many lines are drawn.
/// - Filter to `alerts.filter { $0.isEnabled }` before passing to keep fired alerts visible.
struct AlertOverlayView: View {

    /// Enabled alerts to render. Caller should pre-filter to `isEnabled == true`.
    let alerts: [PriceAlert]
    /// Padded minimum price — matches `priceExtents()` output in ChartContainerView.
    let priceMin: CGFloat
    /// Padded price range — matches `priceExtents()` output in ChartContainerView.
    let priceRange: CGFloat

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Canvas for dashed lines (Canvas doesn't support text, so labels are in ZStack overlay)
                Canvas { ctx, canvasSize in
                    for alert in alerts {
                        let y = priceYCoord(alert.price, in: canvasSize.height)
                        let color: Color = alert.direction == .above ? AppTheme.alertLine : AppTheme.candleDown
                        let opacity: Double = alert.hasTriggered ? 0.35 : 1.0
                        let shading = GraphicsContext.Shading.color(color.opacity(opacity))

                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                        ctx.stroke(
                            path,
                            with: shading,
                            style: StrokeStyle(lineWidth: 1.5, dash: [8, 4])
                        )
                    }
                }
                .frame(width: size.width, height: size.height)

                // Price labels at the right edge — rendered as SwiftUI Text for TV legibility.
                ForEach(alerts) { alert in
                    let y = priceYCoord(alert.price, in: size.height)
                    let labelColor: Color = alert.direction == .above ? AppTheme.alertLine : AppTheme.candleDown
                    let opacity: Double = alert.hasTriggered ? 0.35 : 1.0
                    Text(formatPrice(alert.price))
                        .font(.system(size: 20, weight: .medium).monospacedDigit())
                        .foregroundStyle(labelColor.opacity(opacity))
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.background.opacity(0.75))
                        )
                        .position(x: size.width - 72, y: y)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)   // transparent to Siri Remote focus — must not steal chart interaction
    }

    // MARK: - Geometry helper

    /// Maps a price value to a Y coordinate using the same formula as `CrosshairOverlayView`.
    private func priceYCoord(_ price: Decimal, in height: CGFloat) -> CGFloat {
        let p = CGFloat(NSDecimalNumber(decimal: price).doubleValue)
        guard priceRange > 0 else { return height / 2 }
        return height - ((p - priceMin) / priceRange) * height
    }

    // MARK: - Formatting

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    private func formatPrice(_ price: Decimal) -> String {
        Self.priceFormatter.string(from: price as NSDecimalNumber) ?? "\(price)"
    }
}
