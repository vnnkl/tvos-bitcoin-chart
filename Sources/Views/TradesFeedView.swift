import SwiftUI

/// Displays the most-recent aggregated trades in a scrolling feed.
///
/// Uses compact monospaced data font. Time/price/qty columns
/// right-aligned for scan-readability. BUY = green, SELL = red.
struct TradesFeedView: View {

    let tradeStore: TradeStore

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

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

    private let maxDisplayed = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column headers
            headerRow
                .padding(.bottom, 4)

            if tradeStore.trades.isEmpty {
                Text("Connecting…")
                    .font(AppTheme.dataFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
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
            Text("TIME")
                .frame(width: 90, alignment: .leading)
            Text("PRICE")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("QTY")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(AppTheme.dataHeaderFont)
        .foregroundStyle(AppTheme.textMuted)
    }

    // MARK: - Trade row

    private func tradeRow(trade: AggTrade) -> some View {
        let color = trade.isBuy ? AppTheme.candleUp : AppTheme.candleDown
        return HStack(spacing: 0) {
            Text(Self.timeFormatter.string(from: trade.time))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 105, alignment: .leading)
                .lineLimit(1)
            Text(formatPrice(trade.price))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(formatQty(trade.quantity))
                .foregroundStyle(AppTheme.textPrimary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(AppTheme.dataFont)
        .padding(.vertical, 1)
    }

    // MARK: - Formatters

    private func formatPrice(_ value: Decimal) -> String {
        Self.priceFormatter.string(from: value as NSDecimalNumber) ?? value.description
    }

    private func formatQty(_ value: Decimal) -> String {
        Self.qtyFormatter.string(from: value as NSDecimalNumber) ?? value.description
    }
}
