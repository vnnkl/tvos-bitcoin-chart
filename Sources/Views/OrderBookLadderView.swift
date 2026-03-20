import SwiftUI

/// Displays a live order book bid/ask ladder in the sidebar.
///
/// Reads `orderBookStore.snapshots.last` reactively — `OrderBookStore` is `@Observable`
/// so SwiftUI auto-tracks the dependency without copying into local state.
///
/// Layout (top → bottom):
/// ```
///   Price       Qty         Total       ← column headers (secondary)
///   ───────────────────────────────
///   [ask rows, sorted ascending → lowest ask nearest spread]
///   ── Spread: $X.XX ───────────────   ← spread row
///   [bid rows, sorted descending → highest bid nearest spread]
/// ```
///
/// - Asks: red (`AppTheme.candleDown`)
/// - Bids: green (`AppTheme.candleUp`)
/// - Font: `.title3` minimum with `.monospacedDigit()`
/// - Observability: `orderBookStore.snapshots.count` — 0 means depth stream not connected
struct OrderBookLadderView: View {

    let orderBookStore: OrderBookStore

    private static let priceFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    private static let qtyFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 5
        f.usesGroupingSeparator = false
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column headers
            headerRow
                .padding(.bottom, 6)

            Divider()
                .overlay(AppTheme.textSecondary)
                .padding(.bottom, 4)

            if let snapshot = orderBookStore.snapshots.last {
                ladderContent(snapshot: snapshot)
            } else {
                // Placeholder while waiting for first depth message
                Text("Connecting…")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Price")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Qty")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Total")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(AppTheme.bodyFont)
        .foregroundStyle(AppTheme.textSecondary)
        .monospacedDigit()
    }

    // MARK: - Ladder content

    @ViewBuilder
    private func ladderContent(snapshot: OrderBookSnapshot) -> some View {
        let displayCount = 10

        // Asks sorted ascending (lowest ask = nearest to spread) — we show lowest at BOTTOM
        // so we take the first `displayCount` asks (cheapest) and reverse to put lowest last
        let sortedAsks = snapshot.asks
            .sorted { $0.price < $1.price }
            .prefix(displayCount)

        // Bids sorted descending (highest bid = nearest to spread) at the TOP of bids section
        let sortedBids = snapshot.bids
            .sorted { $0.price > $1.price }
            .prefix(displayCount)

        // Spread calculation
        let lowestAsk  = sortedAsks.first?.price
        let highestBid = sortedBids.first?.price
        let spread: Decimal? = (lowestAsk != nil && highestBid != nil)
            ? lowestAsk! - highestBid!
            : nil

        // Pre-compute cumulative quantities (spread outward = from the spread side)
        let asksCumulative = cumulativeQuantities(Array(sortedAsks))
        let bidsCumulative = cumulativeQuantities(Array(sortedBids))

        VStack(spacing: 0) {
            // Asks (reversed so lowest ask is nearest to spread at the bottom)
            ForEach(Array(zip(Array(sortedAsks), asksCumulative)).reversed(), id: \.0.price) { level, cumQty in
                priceRow(level: level, cumQty: cumQty, color: AppTheme.candleDown)
            }

            // Spread row
            spreadRow(spread: spread)

            // Bids (highest bid first — nearest to spread at the top)
            ForEach(Array(zip(Array(sortedBids), bidsCumulative)), id: \.0.price) { level, cumQty in
                priceRow(level: level, cumQty: cumQty, color: AppTheme.candleUp)
            }
        }
    }

    // MARK: - Row builders

    private func priceRow(level: PriceLevel, cumQty: Decimal, color: Color) -> some View {
        HStack(spacing: 0) {
            Text(formatPrice(level.price))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatQty(level.quantity))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(formatQty(cumQty))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(AppTheme.bodyFont)
        .monospacedDigit()
        .padding(.vertical, 1)
    }

    private func spreadRow(spread: Decimal?) -> some View {
        HStack(spacing: 4) {
            Divider()
                .overlay(AppTheme.textSecondary)
            if let spread {
                Text("Spread: \(formatPrice(spread))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Divider()
                .overlay(AppTheme.textSecondary)
        }
        .frame(height: 22)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    /// Running cumulative sum from index 0 outward (spread side first).
    private func cumulativeQuantities(_ levels: [PriceLevel]) -> [Decimal] {
        var result: [Decimal] = []
        var running: Decimal = 0
        for level in levels {
            running += level.quantity
            result.append(running)
        }
        return result
    }

    private func formatPrice(_ value: Decimal) -> String {
        Self.priceFormatter.string(from: value as NSDecimalNumber) ?? value.description
    }

    private func formatQty(_ value: Decimal) -> String {
        Self.qtyFormatter.string(from: value as NSDecimalNumber) ?? value.description
    }
}
