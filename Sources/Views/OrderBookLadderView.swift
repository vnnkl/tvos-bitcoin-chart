import SwiftUI

/// Displays a live order book bid/ask ladder in the sidebar.
///
/// Uses compact monospaced data font sized to fit price/qty/cumulative columns
/// in the 420pt sidebar without truncation. Each row uses fixed-width columns
/// with right-aligned numbers for scan-readability.
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
        f.minimumFractionDigits = 4
        f.maximumFractionDigits = 4
        f.usesGroupingSeparator = false
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column headers
            headerRow
                .padding(.bottom, 4)

            if let snapshot = orderBookStore.snapshots.last {
                ladderContent(snapshot: snapshot)
            } else {
                Text("Connecting…")
                    .font(AppTheme.dataFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("PRICE")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("QTY")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("TOTAL")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(AppTheme.dataHeaderFont)
        .foregroundStyle(AppTheme.textMuted)
    }

    // MARK: - Ladder content

    @ViewBuilder
    private func ladderContent(snapshot: OrderBookSnapshot) -> some View {
        let displayCount = 7

        let sortedAsks = snapshot.asks
            .sorted { $0.price < $1.price }
            .prefix(displayCount)

        let sortedBids = snapshot.bids
            .sorted { $0.price > $1.price }
            .prefix(displayCount)

        let lowestAsk  = sortedAsks.first?.price
        let highestBid = sortedBids.first?.price
        let spread: Decimal? = (lowestAsk != nil && highestBid != nil)
            ? lowestAsk! - highestBid!
            : nil

        let asksCumulative = cumulativeQuantities(Array(sortedAsks))
        let bidsCumulative = cumulativeQuantities(Array(sortedBids))

        VStack(spacing: 0) {
            // Asks (reversed: lowest ask nearest spread at bottom)
            ForEach(Array(zip(Array(sortedAsks), asksCumulative)).reversed(), id: \.0.price) { level, cumQty in
                priceRow(level: level, cumQty: cumQty, color: AppTheme.candleDown)
            }

            // Spread row
            spreadRow(spread: spread)

            // Bids (highest bid first)
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
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(formatQty(level.quantity))
                .foregroundStyle(AppTheme.textPrimary.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(formatQty(cumQty))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(AppTheme.dataFont)
        .padding(.vertical, 1)
    }

    private func spreadRow(spread: Decimal?) -> some View {
        HStack {
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
            if let spread {
                Text("SPREAD \(formatPrice(spread))")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
                    .fixedSize()
            }
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

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
