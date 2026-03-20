import Foundation
import OSLog
import SwiftUI   // for MoveCommandDirection

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
    let orderBookStore = OrderBookStore()
    let tradeStore = TradeStore()
    var connectionState: ConnectionState = .disconnected
    var chartMode: ChartMode = .candlestick
    var currentSymbol = "BTCUSDT"
    var currentInterval = "1m"
    var isLoading = false
    var error: Error?

    // MARK: - Crosshair / exploration state

    /// True while the user is scrubbing through candle history with the Siri Remote.
    var isExploring: Bool = false

    /// Index into `klineStore.klines` currently under the crosshair.
    /// `nil` when not exploring.
    var crosshairIndex: Int? = nil

    /// The kline under the crosshair, or `nil` when not exploring / index out of range.
    var crosshairKline: Kline? {
        guard let idx = crosshairIndex,
              klineStore.klines.indices.contains(idx) else { return nil }
        return klineStore.klines[idx]
    }

    // MARK: - Private

    private(set) var service: any ExchangeDataService
    private var streamTask: Task<Void, Never>?
    private var depthStreamTask: Task<Void, Never>?
    private var tradesStreamTask: Task<Void, Never>?
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
        depthStreamTask?.cancel()
        depthStreamTask = nil
        tradesStreamTask?.cancel()
        tradesStreamTask = nil
        service.disconnect()
        connectionState = .disconnected
    }

    /// Swap in a new exchange service: tears down all streams, replaces the service, restarts.
    ///
    /// Observable via `viewModel.service` (type comparison) and logs:
    /// `"ChartViewModel.switchExchange newService=<type>"` in the websocket category.
    func switchExchange(_ newService: any ExchangeDataService) {
        let typeName = String(describing: type(of: newService))
        logger.info("ChartViewModel.switchExchange newService=\(typeName)")
        stop()
        service = newService
        start()
    }

    /// Switch to a different interval: stop current stream, reload historical, re-subscribe.
    func switchInterval(_ interval: String) {
        logger.info("Switching interval to \(interval)")
        exitExploration()     // leave crosshair mode when interval changes
        currentInterval = interval
        streamTask?.cancel()
        depthStreamTask?.cancel()
        tradesStreamTask?.cancel()
        streamTask = Task {
            // Clear stores before reloading so the chart shows empty → new data.
            // Depth history is tied to visual context — clear it too when interval changes.
            // Note: aggTrade stream is NOT interval-specific, but lifecycle is cancelled and
            // restarted here to keep all three streams in sync.
            klineStore.loadHistorical([])
            orderBookStore.clear()
            tradeStore.clear()
            await loadAndStream(symbol: currentSymbol, interval: interval)
        }
    }

    // MARK: - Crosshair interaction

    /// Enter exploration mode: freeze auto-scroll, pin crosshair to the rightmost candle.
    func enterExploration() {
        guard !klineStore.klines.isEmpty else { return }
        isExploring = true
        crosshairIndex = klineStore.klines.count - 1
        logger.info("Crosshair entered at index \(self.crosshairIndex ?? -1)")
    }

    /// Move the crosshair one candle left or right. Clamps to the klines array bounds.
    func moveCrosshair(_ direction: MoveCommandDirection) {
        guard isExploring, let current = crosshairIndex else { return }
        let maxIndex = klineStore.klines.count - 1
        switch direction {
        case .left:
            crosshairIndex = max(0, current - 1)
        case .right:
            crosshairIndex = min(maxIndex, current + 1)
        default:
            break  // ignore up/down
        }
    }

    /// Exit exploration mode; return to live view.
    func exitExploration() {
        guard isExploring else { return }
        isExploring = false
        crosshairIndex = nil
        logger.info("Crosshair exited, returning to live view")
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

        // 2a. Start depth stream concurrently — independent of kline stream lifecycle.
        depthStreamTask?.cancel()
        depthStreamTask = Task { [weak self] in
            guard let self else { return }
            let depthStream = service.subscribeOrderBook(symbol: symbol)
            do {
                for try await snapshot in depthStream {
                    guard !Task.isCancelled else { break }
                    orderBookStore.append(snapshot)
                }
            } catch {
                logger.error("Depth stream error: \(error.localizedDescription)")
            }
        }

        // 2b. Start trades stream concurrently — independent of kline stream lifecycle.
        // aggTrade is NOT interval-specific; it streams all trades regardless of kline interval.
        tradesStreamTask?.cancel()
        tradesStreamTask = Task { [weak self] in
            guard let self else { return }
            let tradesStream = service.subscribeTrades(symbol: symbol)
            do {
                for try await trade in tradesStream {
                    guard !Task.isCancelled else { break }
                    tradeStore.append(trade)
                }
            } catch {
                logger.error("Trades stream error: \(error.localizedDescription)")
            }
        }

        // 2c. Subscribe to kline live stream on the current Task.
        let liveStream = service.subscribeKlines(symbol: symbol, interval: interval)
        do {
            for try await kline in liveStream {
                guard !Task.isCancelled else { break }
                let prevCount = klineStore.klines.count
                klineStore.applyLive(kline)
                let newCount = klineStore.klines.count
                // Stability: when exploring, if the klines array didn't grow (a trim happened),
                // the crosshairIndex points to a different candle — decrement to compensate.
                if isExploring, let idx = crosshairIndex, newCount == prevCount, idx > 0 {
                    crosshairIndex = idx - 1
                }
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
