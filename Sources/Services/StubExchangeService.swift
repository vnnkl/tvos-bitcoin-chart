import Foundation

/// Stub implementation of `ExchangeDataService` for testing and multi-exchange validation (R009).
///
/// Returns deterministic fixture data without any network calls — connection failures
/// are impossible by design. Use in tests or when demonstrating exchange swapability
/// without depending on Binance connectivity.
///
/// **Fixture prices (BTC-like):**
/// - open: 42000, high: 42500, low: 41800, close: 42200, volume: 100
///
/// **Inspectable state:**
/// - `connectionState` is always `.connected` — the stub never enters an error state.
/// - `fetchKlines` always returns exactly 5 klines — assert on count in tests.
/// - Each `subscribe*` stream yields exactly 1 item then finishes — consume and count in tests.
final class StubExchangeService: ExchangeDataService, @unchecked Sendable {

    // MARK: - ExchangeDataService

    var connectionState: ConnectionState { .connected }

    func disconnect() {
        // No-op: stub has no real connections to tear down.
    }

    // MARK: - REST

    func fetchKlines(symbol: String, interval: String, limit: Int) async throws -> [Kline] {
        return StubExchangeService.fixtureKlines
    }

    // MARK: - WebSocket Streams

    func subscribeKlines(symbol: String, interval: String) -> AsyncThrowingStream<Kline, Error> {
        let kline = StubExchangeService.fixtureKlines[0]
        return AsyncThrowingStream { continuation in
            continuation.yield(kline)
            continuation.finish()
        }
    }

    func subscribeOrderBook(symbol: String) -> AsyncThrowingStream<OrderBookSnapshot, Error> {
        let snapshot = StubExchangeService.fixtureOrderBook
        return AsyncThrowingStream { continuation in
            continuation.yield(snapshot)
            continuation.finish()
        }
    }

    func subscribeTrades(symbol: String) -> AsyncThrowingStream<AggTrade, Error> {
        let trade = StubExchangeService.fixtureTrade
        return AsyncThrowingStream { continuation in
            continuation.yield(trade)
            continuation.finish()
        }
    }

    // MARK: - Fixture Data

    /// Five fixture klines with realistic BTC price levels.
    static let fixtureKlines: [Kline] = {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return (0..<5).map { i in
            Kline(
                openTime:  base.addingTimeInterval(Double(i) * 60),
                open:      42000,
                high:      42500,
                low:       41800,
                close:     42200,
                volume:    100,
                closeTime: base.addingTimeInterval(Double(i) * 60 + 59.999),
                isClosed:  true
            )
        }
    }()

    /// A single fixture order-book snapshot with one bid and one ask.
    static let fixtureOrderBook: OrderBookSnapshot = OrderBookSnapshot(
        lastUpdateId: 1,
        bids: [PriceLevel(price: 42000, quantity: 1)],
        asks: [PriceLevel(price: 42001, quantity: 1)]
    )

    /// A single fixture aggregate trade (BUY direction).
    static let fixtureTrade: AggTrade = AggTrade(
        aggregateTradeId: 1,
        price:            42200,
        quantity:         Decimal(string: "0.01")!,
        time:             Date(timeIntervalSince1970: 1_700_000_000),
        isBuyerMaker:     false   // isBuyerMaker=false → buyer was taker → BUY
    )
}
