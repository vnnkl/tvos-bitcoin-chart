import Foundation

/// Abstraction boundary over any exchange data source.
/// Implementations: `BinanceService` (S01 T02), future multi-exchange adapters (S05).
///
/// All stream-returning methods produce `AsyncThrowingStream` values so callers can
/// use `for await` with structured concurrency. Streams terminate when `disconnect()`
/// is called or on an unrecoverable error.
protocol ExchangeDataService: Sendable {
    /// Current WebSocket connection state — observable by the view layer.
    var connectionState: ConnectionState { get }

    /// Fetches historical OHLCV klines from the REST endpoint.
    /// - Parameters:
    ///   - symbol: Trading pair, e.g. `"BTCUSDT"`.
    ///   - interval: Kline interval string, e.g. `"1m"`, `"1h"`, `"1d"`.
    ///   - limit:  Number of candles to return (max 1000 per Binance docs).
    func fetchKlines(symbol: String, interval: String, limit: Int) async throws -> [Kline]

    /// Streams live kline updates over WebSocket.
    /// The stream emits one `Kline` per WebSocket message — callers inspect
    /// `kline.isClosed` to distinguish open (in-progress) from closed candles.
    func subscribeKlines(symbol: String, interval: String) -> AsyncThrowingStream<Kline, Error>

    /// Streams live order-book depth updates.
    /// S02 consumes this; the type is stubbed in S01.
    func subscribeOrderBook(symbol: String) -> AsyncThrowingStream<OrderBookSnapshot, Error>

    /// Closes all active WebSocket streams and resets state to `.disconnected`.
    func disconnect()
}
