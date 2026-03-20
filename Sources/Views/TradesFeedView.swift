import SwiftUI

/// Displays the most-recent aggregated trades in a scrolling feed.
///
/// Reads `tradeStore.trades` reactively — `TradeStore` is `@Observable` so SwiftUI
/// auto-tracks the dependency without copying into local state. The array is
/// already most-recent-first (index 0 = newest), so the first rows in the list
/// are always the freshest trades.
///
/// Layout:
/// ```
///   Time        Price       Qty         ← column headers (secondary)
///   ─────────────────────────────────
///   10:23:45   42,000.50   0.015        ← green for BUY, red for SELL
///   10:23:44   41,998.00   0.002
///   …
/// ```
///
/// - BUY trades:  green (`AppTheme.candleUp`)
/// - SELL trades: red   (`AppTheme.candleDown`)
/// - Font: `.title3` minimum with `.monospacedDigit()`
/// - Observability: `tradeStore.trades.count` — 0 means aggTrade stream not connected
struct TradesFeedView: View {

    let tradeStore: TradeStore

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var priceFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }

    private var qtyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 5
        f.usesGroupingSeparator = false
        return f
    }

    // Display at most 25 trades to keep the sidebar compact
    private let maxDisplayed = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column headers
            headerRow
                .padding(.bottom, 6)

            Divider()
                .overlay(AppTheme.textSecondary)
                .padding(.bottom, 4)

            if tradeStore.trades.isEmpty {
                Text("Connecting…")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                // ScrollView is read-only (no selection) — no focusable items inside
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(tradeStore.trades.prefix(maxDisplayed), id: \.aggregateTradeId) { trade in
                            tradeRow(trade: trade)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Time")
                .frame(width: 80, alignment: .leading)
            Text("Price")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Qty")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(AppTheme.bodyFont)
        .foregroundStyle(AppTheme.textSecondary)
        .monospacedDigit()
    }

    // MARK: - Trade row

    private func tradeRow(trade: AggTrade) -> some View {
        let color = trade.isBuy ? AppTheme.candleUp : AppTheme.candleDown
        return HStack(spacing: 0) {
            Text(Self.timeFormatter.string(from: trade.time))
                .foregroundStyle(color)
                .frame(width: 80, alignment: .leading)
            Text(formatPrice(trade.price))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(formatQty(trade.quantity))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(AppTheme.bodyFont)
        .monospacedDigit()
        .padding(.vertical, 1)
    }

    // MARK: - Formatters

    private func formatPrice(_ value: Decimal) -> String {
        priceFormatter.string(from: value as NSDecimalNumber) ?? value.description
    }

    private func formatQty(_ value: Decimal) -> String {
        qtyFormatter.string(from: value as NSDecimalNumber) ?? value.description
    }
}
