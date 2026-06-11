import Foundation
import OSLog

private let logger = Logger(subsystem: "com.bitcointerminal.websocket", category: "BinanceService")

/// Binance implementation of `ExchangeDataService`.
///
/// - REST endpoint: `https://api.binance.com/api/v3/uiKlines`
/// - WebSocket (klines): `wss://stream.binance.com:9443/ws/<symbol>@kline_<interval>`
/// - WebSocket (depth): `wss://stream.binance.com:9443/ws/<symbol>@depth20@100ms`
/// - WebSocket (trades): `wss://stream.binance.com:9443/ws/<symbol>@aggTrade`
final class BinanceService: ExchangeDataService, @unchecked Sendable {

    // MARK: - Configuration

    private let baseURL    = "https://api.binance.com"
    private let wsBaseURL  = "wss://stream.binance.com:9443/ws/"
    private let urlSession: URLSession
    private let webSocketManager: WebSocketManager
    private let depthWebSocketManager: WebSocketManager
    private let tradesWebSocketManager: WebSocketManager

    // MARK: - ExchangeDataService

    var connectionState: ConnectionState {
        webSocketManager.connectionState
    }

    // MARK: - Init

    init(
        urlSession: URLSession = .shared,
        webSocketManager: WebSocketManager = WebSocketManager(),
        depthWebSocketManager: WebSocketManager = WebSocketManager(),
        tradesWebSocketManager: WebSocketManager = WebSocketManager()
    ) {
        self.urlSession = urlSession
        self.webSocketManager = webSocketManager
        self.depthWebSocketManager = depthWebSocketManager
        self.tradesWebSocketManager = tradesWebSocketManager
    }

    // MARK: - REST

    /// Fetches historical klines from `/api/v3/uiKlines`, returns sorted ascending.
    func fetchKlines(symbol: String, interval: String, limit: Int) async throws -> [Kline] {
        guard var components = URLComponents(string: "\(baseURL)/api/v3/uiKlines") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol",   value: symbol),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "limit",    value: String(limit)),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        logger.info("Fetching klines: \(url.absoluteString)")
        let (data, response) = try await urlSession.data(from: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            logger.error("REST fetch failed with status \(http.statusCode)")
            throw URLError(.badServerResponse)
        }

        let raws = try JSONDecoder().decode([BinanceKlineREST].self, from: data)
        let klines = raws
            .map { $0.kline }
            .sorted { $0.openTime < $1.openTime }
        logger.info("Fetched \(klines.count) klines for \(symbol) @ \(interval)")
        return klines
    }

    // MARK: - WebSocket subscriptions

    /// Streams live kline updates for `symbol` at `interval`.
    ///
    /// Connects to `wss://stream.binance.com:9443/ws/<symbol>@kline_<interval>`.
    func subscribeKlines(symbol: String, interval: String) -> AsyncThrowingStream<Kline, Error> {
        subscribe(
            path: "\(symbol.lowercased())@kline_\(interval)",
            label: "kline",
            manager: webSocketManager
        ) { (event: BinanceKlineEvent) in event.kline }
    }

    /// Streams live partial order-book depth snapshots for `symbol`.
    ///
    /// Connects to `wss://stream.binance.com:9443/ws/<symbol>@depth20@100ms`.
    /// Each message is a self-contained top-20 bid/ask snapshot — no reconciliation needed.
    func subscribeOrderBook(symbol: String) -> AsyncThrowingStream<OrderBookSnapshot, Error> {
        subscribe(
            path: "\(symbol.lowercased())@depth20@100ms",
            label: "depth",
            manager: depthWebSocketManager
        ) { (snapshot: OrderBookSnapshot) in snapshot }
    }

    /// Streams live aggregate trades for `symbol`.
    ///
    /// Connects to `wss://stream.binance.com:9443/ws/<symbol>@aggTrade`.
    func subscribeTrades(symbol: String) -> AsyncThrowingStream<AggTrade, Error> {
        subscribe(
            path: "\(symbol.lowercased())@aggTrade",
            label: "aggTrade",
            manager: tradesWebSocketManager
        ) { (trade: AggTrade) in trade }
    }

    /// Connects `manager` to the stream at `path` and runs the messages
    /// through the decoded-stream pipeline.
    ///
    /// - Observability: connect/disconnect/errors logged under subsystem
    ///   `"com.bitcointerminal.websocket"` category `"BinanceService"`.
    ///   Inspect with: `log stream --predicate 'subsystem == "com.bitcointerminal.websocket"'`
    private func subscribe<Event: Decodable & Sendable, Output: Sendable>(
        path: String,
        label: String,
        manager: WebSocketManager,
        transform: @escaping @Sendable (Event) -> Output
    ) -> AsyncThrowingStream<Output, Error> {
        guard let url = URL(string: "\(wsBaseURL)\(path)") else {
            return AsyncThrowingStream { $0.finish(throwing: URLError(.badURL)) }
        }
        logger.info("Subscribing to \(label) stream: \(url.absoluteString)")
        return decodeBinanceEvents(from: manager.connect(to: url), label: label, transform: transform)
    }

    // MARK: - Lifecycle

    /// Disconnects all active WebSocket connections (klines + depth + trades).
    func disconnect() {
        logger.info("BinanceService.disconnect() — disconnecting kline, depth, and trades streams")
        webSocketManager.disconnect()
        depthWebSocketManager.disconnect()
        tradesWebSocketManager.disconnect()
    }
}

// MARK: - Decoded-stream pipeline

/// Shared plumbing for every Binance WebSocket subscription: decodes each text
/// frame of `messages` as `Event`, applies `transform`, and yields the result.
///
/// Semantics (identical to the per-stream loops this replaced):
/// - Non-text frames are skipped.
/// - A frame that fails to decode finishes the stream with that error.
/// - Source termination — normal or throwing — propagates to the consumer.
/// - Cancelling the consumer cancels the decode task.
func decodeBinanceEvents<Event: Decodable & Sendable, Output: Sendable>(
    from messages: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>,
    label: String,
    transform: @escaping @Sendable (Event) -> Output
) -> AsyncThrowingStream<Output, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                for try await message in messages {
                    guard case .string(let text) = message else { continue }
                    guard let data = text.data(using: .utf8) else { continue }
                    let event = try JSONDecoder().decode(Event.self, from: data)
                    continuation.yield(transform(event))
                }
                continuation.finish()
            } catch {
                logger.error("\(label) stream error: \(error.localizedDescription)")
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
