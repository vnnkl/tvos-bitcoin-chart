import SwiftUI

/// Renders a 2-D thermal heatmap of order-book depth history behind the candlestick chart.
///
/// ## Layout contract
/// - **X-axis:** one column per kline slot, right-aligned so the newest snapshot sits at the
///   rightmost kline column. Geometry comes from `CandleLayout(count: klineCount, width:)` —
///   the identical struct used by `CandlestickChartView` and `VolumeBarView`.
/// - **Y-axis:** uses the same inversion formula as `CandlestickChartView`:
///   `y = height - ((price - priceMin) / priceRange) * height`.
///   `priceMin` and `priceRange` are the 5%-padded extents computed once by
///   `ChartContainerView` (T04) and passed to both this view and `CandlestickChartView`.
/// - **Color:** logarithmic normalization `log(1+qty)/log(1+maxQty)` mapped through a
///   6-stop thermal gradient: dark-blue → blue → teal → green → yellow → white.
/// - `.drawingGroup()` composites all cells into a single Metal-backed layer before blending.
///
/// ## Observability
/// - When `snapshots` is empty or `priceRange == 0`, the Canvas draws nothing (transparent).
///   Check `orderBookStore.snapshots.count` in the debugger to confirm depth data is arriving.
/// - If the heatmap appears but misaligned with candles, verify that `klineCount` equals
///   `klineStore.klines.count` and `priceMin`/`priceRange` match `CandlestickChartView`'s
///   `priceExtents` output.
struct DepthHeatmapView: View {

    /// All stored depth snapshots from `OrderBookStore`, newest last.
    let snapshots: [OrderBookSnapshot]
    /// Number of kline candles currently displayed — drives `CandleLayout` slot geometry.
    let klineCount: Int
    /// Minimum price from `priceExtents` (5%-padded). Matches `CandlestickChartView`.
    let priceMin: CGFloat
    /// Price range from `priceExtents` (5%-padded). Matches `CandlestickChartView`.
    let priceRange: CGFloat

    var body: some View {
        Canvas { context, size in
            render(context: context, size: size)
        }
        .opacity(AppTheme.heatmapOpacity)
        .drawingGroup()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rendering

    private func render(context: GraphicsContext, size: CGSize) {
        guard !snapshots.isEmpty, klineCount > 0, priceRange > 0 else { return }

        let height = size.height
        let layout = CandleLayout(count: klineCount, width: size.width)

        // Cell height: a small fixed size gives a smooth thermal appearance.
        // ~3–5 pt is ideal; we clamp to at least 2 pt so cells are always visible.
        let cellHeight: CGFloat = max(height / 100, 2)

        // Pre-compute logarithmic max-quantity for normalisation across all visible levels.
        // We compute this in one pass before rendering so every cell is normalised
        // relative to the global maximum across the entire visible snapshot set.
        var maxQtyLog: Double = 0
        for snapshot in snapshots {
            for level in snapshot.bids + snapshot.asks {
                let qty = NSDecimalNumber(decimal: level.quantity).doubleValue
                let l = log(1 + qty)
                if l > maxQtyLog { maxQtyLog = l }
            }
        }
        guard maxQtyLog > 0 else { return }

        // Right-align snapshots within the kline column grid:
        //   newest snapshot  → column klineCount - 1
        //   oldest snapshot  → column klineCount - snapshots.count
        let startColumn = klineCount - snapshots.count

        for (i, snapshot) in snapshots.enumerated() {
            let columnIndex = startColumn + i
            guard columnIndex >= 0 else { continue } // snapshot older than visible range

            let centerX = layout.centerX(for: columnIndex)
            let x = centerX - layout.slotWidth / 2
            let w = layout.slotWidth

            for level in snapshot.bids + snapshot.asks {
                let p = CGFloat(NSDecimalNumber(decimal: level.price).doubleValue)

                // Clip levels outside the visible price range.
                guard p >= priceMin, p <= priceMin + priceRange else { continue }

                // Y-axis inversion: same formula as CandlestickChartView.priceY
                let y = height - ((p - priceMin) / priceRange) * height

                let qty = NSDecimalNumber(decimal: level.quantity).doubleValue
                let normalized = log(1 + qty) / maxQtyLog

                let rect = CGRect(x: x, y: y - cellHeight / 2, width: w, height: cellHeight)
                context.fill(Path(rect), with: .color(thermalColor(normalized: normalized)))
            }
        }
    }

    // MARK: - Thermal color mapping

    /// Maps a normalised quantity value (0–1) to a thermal colour through a 6-stop gradient.
    ///
    /// Gradient stops (linear in the 0–1 domain):
    /// - 0.0: heatmapCold    (near-black dark blue)
    /// - 0.2: heatmapCool    (blue)
    /// - 0.4: heatmapMedium  (teal-green)
    /// - 0.6: heatmapWarm    (green)
    /// - 0.8: heatmapHot     (yellow)
    /// - 1.0: heatmapExtreme (white — liquidity walls)
    private func thermalColor(normalized t: Double) -> Color {
        let stops: [(threshold: Double, color: Color)] = [
            (0.0, AppTheme.heatmapCold),
            (0.2, AppTheme.heatmapCool),
            (0.4, AppTheme.heatmapMedium),
            (0.6, AppTheme.heatmapWarm),
            (0.8, AppTheme.heatmapHot),
            (1.0, AppTheme.heatmapExtreme),
        ]

        // Clamp to [0, 1].
        let clamped = max(0.0, min(1.0, t))

        // Find the two bracketing stops.
        for segIdx in 1 ..< stops.count {
            let lo = stops[segIdx - 1]
            let hi = stops[segIdx]
            if clamped <= hi.threshold {
                let span = hi.threshold - lo.threshold
                let f = span > 0 ? (clamped - lo.threshold) / span : 0
                return interpolate(from: lo.color, to: hi.color, fraction: f)
            }
        }
        return AppTheme.heatmapExtreme
    }

    /// Linear interpolation between two `Color` values.
    /// Both colours are expected to be in the sRGB colour space.
    private func interpolate(from a: Color, to b: Color, fraction f: Double) -> Color {
        // Resolve to concrete component values via UIColor → CGColor.
        let (ar, ag, ab, aa) = components(of: a)
        let (br, bg, bb, ba) = components(of: b)
        return Color(
            red:     ar + (br - ar) * f,
            green:   ag + (bg - ag) * f,
            blue:    ab + (bb - ab) * f,
            opacity: aa + (ba - aa) * f
        )
    }

    /// Extracts (r, g, b, a) Double components from a SwiftUI `Color` in sRGB space.
    private func components(of color: Color) -> (Double, Double, Double, Double) {
        // Color.resolve(in:) is iOS 17+/tvOS 17+ — available on our deployment target.
        // We can't call it here (no EnvironmentValues in a pure function), so we use the
        // stored RGB constants directly. Since all heatmap colours are created with explicit
        // `Color(red:green:blue:)` initialisers, we can extract them via UIColor.
#if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
#else
        // Fallback — should not be reached on tvOS.
        return (0, 0, 0, 1)
#endif
    }
}
