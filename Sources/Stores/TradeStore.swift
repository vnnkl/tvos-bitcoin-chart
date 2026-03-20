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
