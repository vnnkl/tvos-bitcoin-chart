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

    // MARK: - WebSocket: Klines

    /// Streams live kline updates for `symbol` at `interval`.
    func subscribeKlines(symbol: String, interval: String) -> AsyncThrowingStream<Kline, Error> {
        let path = "\(symbol.lowercased())@kline_\(interval)"
        guard let url = URL(string: "\(wsBaseURL)\(path)") else {
            return AsyncThrowingStream { $0.finish(throwing: URLError(.badURL)) }
        }

        logger.info("Subscribing to kline stream: \(url.absoluteString)")
        let messageStream = webSocketManager.connect(to: url)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await message in messageStream {
                        guard case .string(let text) = message else { continue }
                        guard let data = text.data(using: .utf8) else { continue }
                        let event = try JSONDecoder().decode(BinanceKlineEvent.self, from: data)
                        continuation.yield(event.kline)
                    }
                    continuation.finish()
                } catch {
                    logger.error("kline stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - WebSocket: Order Book Depth

    /// Streams live partial order-book depth snapshots for `symbol`.
    ///
    /// Connects to `wss://stream.binance.com:9443/ws/<symbol>@depth20@100ms`.
    /// Each message is a self-contained top-20 bid/ask snapshot — no reconciliation needed.
    ///
    /// - Observability: connect/disconnect/errors logged under subsystem
    ///   `"com.bitcointerminal.websocket"` category `"BinanceService"`.
    ///   Inspect with: `log stream --predicate 'subsystem == "com.bitcointerminal.websocket"'`
    func subscribeOrderBook(symbol: String) -> AsyncThrowingStream<OrderBookSnapshot, Error> {
        let path = "\(symbol.lowercased())@depth20@100ms"
        guard let url = URL(string: "\(wsBaseURL)\(path)") else {
            return AsyncThrowingStream { $0.finish(throwing: URLError(.badURL)) }
        }

        logger.info("Subscribing to depth stream: \(url.absoluteString)")
        let messageStream = depthWebSocketManager.connect(to: url)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await message in messageStream {
                        guard case .string(let text) = message else { continue }
                        guard let data = text.data(using: .utf8) else { continue }
                        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: data)
                        continuation.yield(snapshot)
                    }
                    continuation.finish()
                } catch {
                    logger.error("depth stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - WebSocket: Aggregate Trades

    /// Streams live aggregate trades for `symbol`.
    ///
    /// Connects to `wss://stream.binance.com:9443/ws/<symbol>@aggTrade`.
    ///
    /// - Observability: connect/disconnect/errors logged under subsystem
    ///   `"com.bitcointerminal.websocket"` category `"BinanceService"`.
    func subscribeTrades(symbol: String) -> AsyncThrowingStream<AggTrade, Error> {
        let path = "\(symbol.lowercased())@aggTrade"
        guard let url = URL(string: "\(wsBaseURL)\(path)") else {
            return AsyncThrowingStream { $0.finish(throwing: URLError(.badURL)) }
        }

        logger.info("Subscribing to aggTrade stream: \(url.absoluteString)")
        let messageStream = tradesWebSocketManager.connect(to: url)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await message in messageStream {
                        guard case .string(let text) = message else { continue }
                        guard let data = text.data(using: .utf8) else { continue }
                        let trade = try JSONDecoder().decode(AggTrade.self, from: data)
                        continuation.yield(trade)
                    }
                    continuation.finish()
                } catch {
                    logger.error("aggTrade stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
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
