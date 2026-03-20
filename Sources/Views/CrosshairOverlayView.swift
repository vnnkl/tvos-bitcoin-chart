import SwiftUI

/// Canvas overlay that draws a vertical + horizontal crosshair at the selected
/// candle, plus an OHLCV tooltip box.
///
/// Uses the same `CandleLayout` and `priceY` geometry as `CandlestickChartView`
/// so the crosshair snaps exactly to candle centers.
///
/// **Input contract:**
/// - `klines`         — full kline array (must be non-empty; caller guards)
/// - `crosshairIndex` — index of the candle under the crosshair (0…klines.count-1)
/// - `priceMin`       — padded minimum price (from `priceExtents`)
/// - `priceRange`     — padded price range  (from `priceExtents`)
struct CrosshairOverlayView: View {

    let klines: [Kline]
    let crosshairIndex: Int
    let priceMin: CGFloat
    let priceRange: CGFloat

    var body: some View {
        GeometryReader { geo in
            let size  = geo.size
            let kline = klines[crosshairIndex]
            let layout = CandleLayout(count: klines.count, width: size.width)
            let cx    = layout.centerX(for: crosshairIndex)
            let cy    = priceYCoord(kline.close, in: size.height)

            // ── Canvas: vertical line, horizontal line, intersection dot ──
            Canvas { ctx, canvasSize in
                let lineColor = GraphicsContext.Shading.color(
                    AppTheme.textSecondary.opacity(0.8)
                )
                let lineWidth: CGFloat = 1.5

                // Vertical line
                var vPath = Path()
                vPath.move(to:    CGPoint(x: cx, y: 0))
                vPath.addLine(to: CGPoint(x: cx, y: canvasSize.height))
                ctx.stroke(vPath, with: lineColor, lineWidth: lineWidth)

                // Horizontal line
                var hPath = Path()
                hPath.move(to:    CGPoint(x: 0,                y: cy))
                hPath.addLine(to: CGPoint(x: canvasSize.width, y: cy))
                ctx.stroke(hPath, with: lineColor, lineWidth: lineWidth)

                // Intersection dot (white, 4 pt radius)
                let dotRadius: CGFloat = 4
                let dotRect = CGRect(
                    x: cx - dotRadius, y: cy - dotRadius,
                    width: dotRadius * 2, height: dotRadius * 2
                )
                ctx.fill(Path(ellipseIn: dotRect), with: .color(.white))
            }
            .frame(width: size.width, height: size.height)

            // ── OHLCV tooltip ──────────────────────────────────────────
            tooltipView(kline: kline, canvasSize: size, crosshairX: cx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)   // transparent to touch/focus so chart ZStack stays focusable
    }

    // MARK: - Tooltip

    @ViewBuilder
    private func tooltipView(kline: Kline, canvasSize: CGSize, crosshairX: CGFloat) -> some View {
        let tooltipWidth: CGFloat = 220
        let tooltipHeight: CGFloat = 180  // approximate; VStack sizes naturally
        let margin: CGFloat = 16

        // Place to the right if crosshair is in the left half, else to the left.
        let inRightHalf = crosshairX > canvasSize.width / 2
        let tooltipX: CGFloat = inRightHalf
            ? crosshairX - tooltipWidth - margin
            : crosshairX + margin

        // Clamp Y so the tooltip never clips the top edge.
        let rawY = priceYCoord(kline.close, in: canvasSize.height) - tooltipHeight / 2
        let tooltipY = max(margin, min(rawY, canvasSize.height - tooltipHeight - margin))

        OHLCVTooltip(kline: kline)
            .frame(width: tooltipWidth)
            .position(
                x: tooltipX + tooltipWidth / 2,
                y: tooltipY + tooltipHeight / 2
            )
    }

    // MARK: - Geometry helper

    /// Maps a price value to a Y coordinate on the canvas (same formula as CandlestickChartView).
    private func priceYCoord(_ price: Decimal, in height: CGFloat) -> CGFloat {
        let p = CGFloat(NSDecimalNumber(decimal: price).doubleValue)
        guard priceRange > 0 else { return height / 2 }
        return height - ((p - priceMin) / priceRange) * height
    }
}

// MARK: - OHLCV Tooltip sub-view

/// Dark card showing Open / High / Low / Close / Volume for the selected candle.
private struct OHLCVTooltip: View {

    let kline: Kline

    private static let priceFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    private static let volFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 4
        f.maximumFractionDigits = 4
        f.usesGroupingSeparator = true
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.dateFormatter.string(from: kline.openTime))
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)

            Divider().background(AppTheme.textSecondary.opacity(0.4))

            row(label: "O", value: format(kline.open), color: AppTheme.textPrimary)
            row(label: "H", value: format(kline.high), color: AppTheme.candleUp)
            row(label: "L", value: format(kline.low),  color: AppTheme.candleDown)
            row(label: "C", value: format(kline.close), color: closeColor)
            row(label: "V", value: formatVol(kline.volume), color: AppTheme.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                .fill(AppTheme.background.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                        .stroke(AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func row(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20, alignment: .leading)
            Text(value)
                .font(AppTheme.bodyFont)
                .foregroundStyle(color)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var closeColor: Color {
        kline.close >= kline.open ? AppTheme.candleUp : AppTheme.candleDown
    }

    private func format(_ price: Decimal) -> String {
        Self.priceFormatter.string(from: price as NSDecimalNumber) ?? "\(price)"
    }

    private func formatVol(_ vol: Decimal) -> String {
        Self.volFormatter.string(from: vol as NSDecimalNumber) ?? "\(vol)"
    }
}
