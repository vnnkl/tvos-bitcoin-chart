import Foundation

/// Observable store that holds a bounded, most-recent-first ring buffer of `AggTrade` values.
///
/// New trades are inserted at the **front** (index 0) so the freshest trade is always
/// first — matching the typical trades-feed display of newest-at-top.
/// This is intentionally the inverse of `KlineStore` and `OrderBookStore`, which are
/// chronological (oldest first). The trades feed UI reads `trades[0]` as the current trade.
///
/// The array never exceeds `maxTrades` — the oldest trades are trimmed from the back.
///
/// - Observability: `trades.count` — 0 means the aggTrade stream is not connected or
///   has not yet received its first message. Check os.log subsystem
///   `"com.bitcointerminal.websocket"` for stream lifecycle events.
@Observable
final class TradeStore: @unchecked Sendable {

    // MARK: - Configuration

    /// Maximum number of trades to retain. Oldest are dropped from the back.
    let maxTrades: Int

    // MARK: - State

    /// Live trades, most-recent-first. `trades[0]` is the newest trade.
    private(set) var trades: [AggTrade] = []

    // MARK: - Init

    init(maxTrades: Int = 100) {
        self.maxTrades = maxTrades
    }

    // MARK: - Computed

    /// Taker-buy share of traded volume across the most recent `window` trades, in 0…1.
    ///
    /// Weighted by quantity, not trade count, so one large market sell outweighs
    /// many small buys. Returns 0.5 when no trades are present so pressure gauges
    /// render balanced.
    func buyVolumeRatio(window: Int = 50) -> Double {
        let recent = trades.prefix(window)
        guard !recent.isEmpty else { return 0.5 }

        let (buys, total) = recent.reduce((Decimal(0), Decimal(0))) { acc, trade in
            (acc.0 + (trade.isBuy ? trade.quantity : 0), acc.1 + trade.quantity)
        }
        guard total > 0 else { return 0.5 }
        return NSDecimalNumber(decimal: buys).doubleValue
             / NSDecimalNumber(decimal: total).doubleValue
    }

    // MARK: - Data ingestion

    /// Prepends a new trade at index 0, trimming oldest entries to stay within `maxTrades`.
    func append(_ trade: AggTrade) {
        trades.insert(trade, at: 0)
        if trades.count > maxTrades {
            trades.removeLast(trades.count - maxTrades)
        }
    }

    /// Resets the store to empty — called when starting a new stream lifecycle.
    func clear() {
        trades = []
    }
}
