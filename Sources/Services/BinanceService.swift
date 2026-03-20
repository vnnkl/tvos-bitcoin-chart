import Foundation
import OSLog

private let logger = Logger(subsystem: "com.bitcointerminal.websocket", category: "BinanceService")

/// Binance implementation of `ExchangeDataService`.
///
/// - REST endpoint: `https://api.binance.com/api/v3/uiKlines`
/// - WebSocket: `wss://stream.binance.com:9443/ws/<symbol>@kline_<interval>`
final class BinanceService: ExchangeDataService, @unchecked Sendable {

    // MARK: - Configuration

    private let baseURL    = "https://api.binance.com"
    private let wsBaseURL  = "wss://stream.binance.com:9443/ws/"
    private let urlSession: URLSession
    private let webSocketManager: WebSocketManager

    // MARK: - ExchangeDataService

    var connectionState: ConnectionState {
        webSocketManager.connectionState
    }

    // MARK: - Init

    init(urlSession: URLSession = .shared, webSocketManager: WebSocketManager = WebSocketManager()) {
        self.urlSession = urlSession
        self.webSocketManager = webSocketManager
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

    // MARK: - WebSocket

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

    /// Order-book stream stub — implemented in S02.
    func subscribeOrderBook(symbol: String) -> AsyncThrowingStream<OrderBookSnapshot, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    /// Disconnects all active WebSocket connections.
    func disconnect() {
        logger.info("BinanceService.disconnect()")
        webSocketManager.disconnect()
    }
}
