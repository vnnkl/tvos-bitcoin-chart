import Foundation
import OSLog

private let logger = Logger(subsystem: "com.bitcointerminal.websocket", category: "ChartViewModel")

/// Chart display modes.
enum ChartMode: String, CaseIterable, Sendable {
    case candlestick
    case line
}

/// Orchestrates the full data lifecycle: REST historical load → live WebSocket stream.
///
/// Annotated `@MainActor` so all `@Observable` mutations occur on the main thread
/// and SwiftUI views can safely observe them without extra dispatch.
@Observable
@MainActor
final class ChartViewModel {

    // MARK: - Public state (observed by views)

    let klineStore = KlineStore()
    var connectionState: ConnectionState = .disconnected
    var chartMode: ChartMode = .candlestick
    var currentSymbol = "BTCUSDT"
    var currentInterval = "1m"
    var isLoading = false
    var error: Error?

    // MARK: - Private

    private let service: any ExchangeDataService
    private var streamTask: Task<Void, Never>?
    private var stateObserverTask: Task<Void, Never>?

    // MARK: - Init

    init(service: any ExchangeDataService = BinanceService()) {
        self.service = service
    }

    // MARK: - Lifecycle

    /// Start: fetch historical klines, then subscribe to live updates.
    func start() {
        logger.info("ChartViewModel.start() symbol=\(self.currentSymbol) interval=\(self.currentInterval)")
        streamTask?.cancel()
        streamTask = Task {
            await loadAndStream(symbol: currentSymbol, interval: currentInterval)
        }
    }

    /// Stop streaming and disconnect.
    func stop() {
        logger.info("ChartViewModel.stop()")
        streamTask?.cancel()
        streamTask = nil
        service.disconnect()
        connectionState = .disconnected
    }

    /// Switch to a different interval: stop current stream, reload historical, re-subscribe.
    func switchInterval(_ interval: String) {
        logger.info("Switching interval to \(interval)")
        currentInterval = interval
        streamTask?.cancel()
        streamTask = Task {
            // Clear store before reloading so the chart shows empty → new data
            klineStore.loadHistorical([])
            await loadAndStream(symbol: currentSymbol, interval: interval)
        }
    }

    // MARK: - Private: data pipeline

    private func loadAndStream(symbol: String, interval: String) async {
        isLoading = true
        error = nil
        connectionState = service.connectionState

        // 1. Fetch historical klines via REST
        do {
            let historical = try await service.fetchKlines(symbol: symbol, interval: interval, limit: 500)
            klineStore.loadHistorical(historical)
            logger.info("Loaded \(historical.count) historical klines")
        } catch {
            logger.error("REST fetch failed: \(error.localizedDescription)")
            self.error = error
            isLoading = false
            return
        }
        isLoading = false

        // 2. Subscribe to live WebSocket stream.
        // WebSocketManager handles reconnection internally; we just consume the stream.
        // Any thrown error is caught here — the ViewModel records it and the
        // ConnectionState enum surface lets the view show the current health.
        let liveStream = service.subscribeKlines(symbol: symbol, interval: interval)
        do {
            for try await kline in liveStream {
                guard !Task.isCancelled else { break }
                klineStore.applyLive(kline)
                connectionState = service.connectionState
            }
        } catch {
            logger.error("Live stream error: \(error.localizedDescription)")
            self.error = error
        }

        // Stream ended (disconnected or cancelled)
        connectionState = service.connectionState
        logger.info("Live stream ended for \(symbol)@\(interval)")
    }
}
