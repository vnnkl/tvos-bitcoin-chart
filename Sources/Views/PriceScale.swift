import Foundation
import CoreGraphics

/// Maps prices to canvas Y coordinates (and back) for every chart view.
///
/// **Coordinate system:** Canvas origin is top-left; the price axis runs
/// bottom-to-top, so high prices map to low Y values.
///
/// **Degenerate ranges:** A zero or negative `priceRange` maps every price to
/// the vertical center instead of dividing by zero.
///
/// `priceMin` / `priceRange` come from `priceExtents` (already 5 %-padded) so
/// candles, overlays, heatmap, and axis share pixel-identical geometry.
struct PriceScale {
    let priceMin: CGFloat
    let priceRange: CGFloat

    init(priceMin: CGFloat, priceRange: CGFloat) {
        self.priceMin = priceMin
        self.priceRange = priceRange
    }

    /// Builds a scale from the padded extents of `klines`.
    init(klines: [Kline]) {
        let (min, range) = priceExtents(klines)
        self.init(priceMin: min, priceRange: range)
    }

    /// Y coordinate of `price` on a canvas of `height`.
    func y(_ price: Decimal, in height: CGFloat) -> CGFloat {
        y(CGFloat(NSDecimalNumber(decimal: price).doubleValue), in: height)
    }

    /// Y coordinate of `price` on a canvas of `height`.
    func y(_ price: CGFloat, in height: CGFloat) -> CGFloat {
        guard priceRange > 0 else { return height / 2 }
        return height - ((price - priceMin) / priceRange) * height
    }

    /// Inverse mapping: the price at canvas coordinate `y`.
    func price(atY y: CGFloat, in height: CGFloat) -> CGFloat {
        guard height > 0, priceRange > 0 else { return priceMin }
        return priceMin + ((height - y) / height) * priceRange
    }
}

/// Finds the minimum low and price range across all klines, with 5 % padding.
///
/// Free function so `ChartContainerView` and every chart view derive the same
/// padded extents, keeping their Y-axes identical.
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
