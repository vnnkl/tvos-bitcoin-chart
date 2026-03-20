import SwiftUI

// MARK: - Testable computation (free function — no SwiftUI dependency)

/// Converts raw price levels into cumulative depth curve points.
///
/// Extracted as a free function so unit tests can call it directly without
/// triggering the SwiftUI / CoreGraphics rendering stack in the test runner.
///
/// - Parameters:
///   - levels: The raw `[PriceLevel]` array (bids or asks).
///   - sortDescending: Pass `true` for bids (highest price first),
///     `false` for asks (lowest price first).
/// - Returns: Array of `(price, cumulativeQty)` tuples in the requested sort order.
///   Returns an empty array when `levels` is empty.
func depthCumulativeLevels(
    from levels: [PriceLevel],
    sortDescending: Bool
) -> [(price: CGFloat, cumulativeQty: CGFloat)] {
    guard !levels.isEmpty else { return [] }

    let sorted = levels.sorted {
        sortDescending
            ? $0.price > $1.price
            : $0.price < $1.price
    }

    var result: [(price: CGFloat, cumulativeQty: CGFloat)] = []
    result.reserveCapacity(sorted.count)
    var runningSum: CGFloat = 0

    for level in sorted {
        let price = CGFloat(NSDecimalNumber(decimal: level.price).doubleValue)
        let qty   = CGFloat(NSDecimalNumber(decimal: level.quantity).doubleValue)
        runningSum += qty
        result.append((price: price, cumulativeQty: runningSum))
    }

    return result
}

// MARK: - View

/// Renders cumulative bid/ask depth curves as filled areas on a SwiftUI `Canvas`.
///
/// - **Bids** (green, left side): price-descending sort, so the curve starts at
///   the best bid and extends left toward deeper support levels.
/// - **Asks** (red, right side): price-ascending sort, so the curve starts at
///   the best ask and extends right toward deeper resistance levels.
///
/// Cumulative computation is delegated to `depthCumulativeLevels(from:sortDescending:)`
/// (a free function) so it remains testable without importing SwiftUI.
struct DepthChartView: View {

    let snapshot: OrderBookSnapshot?

    // MARK: - View Body

    var body: some View {
        Canvas { context, size in
            guard let snapshot else { return }

            let bidLevels = depthCumulativeLevels(from: snapshot.bids, sortDescending: true)
            let askLevels = depthCumulativeLevels(from: snapshot.asks, sortDescending: false)

            guard !bidLevels.isEmpty, !askLevels.isEmpty else { return }

            let minPrice = bidLevels.last?.price  ?? 0   // deepest bid = lowest price
            let maxPrice = askLevels.last?.price  ?? 0   // deepest ask = highest price
            let priceRange = maxPrice - minPrice
            guard priceRange > 0 else { return }

            let maxBidCum = bidLevels.last?.cumulativeQty ?? 0
            let maxAskCum = askLevels.last?.cumulativeQty ?? 0
            let maxCumQty = max(maxBidCum, maxAskCum)
            guard maxCumQty > 0 else { return }

            let width  = size.width
            let height = size.height

            // Coordinate mappers
            func xForPrice(_ price: CGFloat) -> CGFloat {
                (price - minPrice) / priceRange * width
            }
            func yForQty(_ qty: CGFloat) -> CGFloat {
                height - (qty / maxCumQty) * height
            }

            // --- Bid filled path (green) ---
            let bidPoints = bidLevels.map { CGPoint(x: xForPrice($0.price), y: yForQty($0.cumulativeQty)) }

            var bidFill = Path()
            bidFill.move(to: CGPoint(x: bidPoints[0].x, y: height))
            for pt in bidPoints { bidFill.addLine(to: pt) }
            bidFill.addLine(to: CGPoint(x: bidPoints[bidPoints.count - 1].x, y: height))
            bidFill.closeSubpath()

            context.fill(bidFill, with: .color(AppTheme.candleUp.opacity(0.3)))

            var bidEdge = Path()
            bidEdge.move(to: bidPoints[0])
            for pt in bidPoints.dropFirst() { bidEdge.addLine(to: pt) }
            context.stroke(bidEdge, with: .color(AppTheme.candleUp), lineWidth: 1.5)

            // --- Ask filled path (red) ---
            let askPoints = askLevels.map { CGPoint(x: xForPrice($0.price), y: yForQty($0.cumulativeQty)) }

            var askFill = Path()
            askFill.move(to: CGPoint(x: askPoints[0].x, y: height))
            for pt in askPoints { askFill.addLine(to: pt) }
            askFill.addLine(to: CGPoint(x: askPoints[askPoints.count - 1].x, y: height))
            askFill.closeSubpath()

            context.fill(askFill, with: .color(AppTheme.candleDown.opacity(0.3)))

            var askEdge = Path()
            askEdge.move(to: askPoints[0])
            for pt in askPoints.dropFirst() { askEdge.addLine(to: pt) }
            context.stroke(askEdge, with: .color(AppTheme.candleDown), lineWidth: 1.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }
}
