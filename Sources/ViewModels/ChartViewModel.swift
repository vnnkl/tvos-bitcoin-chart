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

    /// Aggregate connection health across kline, depth, and trades streams.
    /// Returns the worst state: `.connected` only if the service reports connected
    /// AND all three stream tasks are alive. `.reconnecting` if any stream is in recovery.
    var connectionHealth: ConnectionState {
        let serviceState = service.connectionState
        // If the service itself is not connected, that's the overall state.
        if serviceState != .connected {
            return serviceState
        }
        // Service reports connected but check if all stream tasks are alive.
        // A nil or cancelled task means that stream is effectively disconnected.
        let depthAlive = depthStreamTask != nil && !(depthStreamTask?.isCancelled ?? true)
        let tradesAlive = tradesStreamTask != nil && !(tradesStreamTask?.isCancelled ?? true)
        if !depthAlive || !tradesAlive {
            return .reconnecting   // Service OK but subsidiary streams are down
        }
        return .connected
    }
    var currentSymbol = "BTCUSDT"
    var currentInterval = "1m"
    var isLoading = false
    var error: Error?

    // MARK: - Zoom state

    /// Current zoom level. Positive = zoomed in (fewer candles), negative = zoomed out (more candles).
    /// Clamped to −3…+5.
    var zoomLevel: Int = 0

    /// The subset of klines currently visible given the zoom level.
    /// Zoom applies `pow(0.7, zoomLevel)` as a fraction of the full kline array,
    /// clamped to a minimum of 20 candles and a maximum of the full array.
    /// Always returns a suffix of `klineStore.klines` (most-recent candles).
    var visibleKlines: [Kline] {
        let base = klineStore.klines.count
        guard base > 0 else { return [] }
        let factor = pow(0.7, Double(zoomLevel))
        let count = max(20, min(base, Int(Double(base) * factor)))
        return Array(klineStore.klines.suffix(count))
    }

    /// Zoom in: show fewer, larger candles. Clamps at +5.
    /// If exploring, crosshairIndex is clamped to the new visible range.
    func zoomIn() {
        guard zoomLevel < 5 else { return }
        zoomLevel += 1
        clampCrosshairToVisible()
        logger.info("Zoom in → level=\(self.zoomLevel) visible=\(self.visibleKlines.count)")
    }

    /// Zoom out: show more candles, broader view. Clamps at −3.
    /// If exploring, crosshairIndex is clamped to the new visible range.
    func zoomOut() {
        guard zoomLevel > -3 else { return }
        zoomLevel -= 1
        clampCrosshairToVisible()
        logger.info("Zoom out → level=\(self.zoomLevel) visible=\(self.visibleKlines.count)")
    }

    private func clampCrosshairToVisible() {
        guard isExploring, let idx = crosshairIndex, !visibleKlines.isEmpty else { return }
        crosshairIndex = min(idx, visibleKlines.count - 1)
    }

    // MARK: - Crosshair / exploration state

    /// True while the user is scrubbing through candle history with the Siri Remote.
    var isExploring: Bool = false

    /// Index into `klineStore.klines` currently under the crosshair.
    /// `nil` when not exploring.
    var crosshairIndex: Int? = nil

    /// The kline under the crosshair, or `nil` when not exploring / index out of range.
    /// Indexes into `visibleKlines`, not the full `klineStore.klines` array.
    var crosshairKline: Kline? {
        guard let idx = crosshairIndex,
              visibleKlines.indices.contains(idx) else { return nil }
        return visibleKlines[idx]
    }

    // MARK: - Alert state

    /// Injected by ContentView so the ViewModel can fire crossing checks on each live tick.
    var alertStore: AlertStore?

    /// The most recently fired alert — drives `AlertBannerView`. `nil` when no banner is showing.
    /// Auto-cleared after 3 seconds by a `Task.sleep` spawned on each fire.
    var triggeredAlert: PriceAlert? = nil

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

    /// Enter exploration mode: freeze auto-scroll, pin crosshair to the rightmost visible candle.
    func enterExploration() {
        guard !visibleKlines.isEmpty else { return }
        isExploring = true
        crosshairIndex = visibleKlines.count - 1
        logger.info("Crosshair entered at index \(self.crosshairIndex ?? -1) (visibleKlines.count=\(self.visibleKlines.count))")
    }

    /// Move the crosshair one candle left or right. Clamps to the visibleKlines bounds.
    func moveCrosshair(_ direction: MoveCommandDirection) {
        guard isExploring, let current = crosshairIndex else { return }
        let maxIndex = visibleKlines.count - 1
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
                // Capture price BEFORE applying the live update for crossing detection.
                let prevPrice = klineStore.currentPrice
                klineStore.applyLive(kline)
                let newCount = klineStore.klines.count
                // Stability: when exploring, if the visible array didn't grow (a trim happened),
                // the crosshairIndex points to a different candle — decrement to compensate.
                // We check visibleKlines.count because crosshairIndex indexes into visibleKlines.
                if isExploring, let idx = crosshairIndex, visibleKlines.count == prevCount, idx > 0 {
                    crosshairIndex = idx - 1
                }
                connectionState = service.connectionState

                // Alert crossing detection: check every enabled, un-triggered alert.
                if let store = alertStore {
                    let fired = store.check(
                        currentPrice: klineStore.currentPrice,
                        previousPrice: prevPrice
                    )
                    if let first = fired.first {
                        logger.info(
                            "Alert fired: id=\(first.id) price=\(first.price) direction=\(first.direction.rawValue)"
                        )
                        triggeredAlert = first
                        // Auto-dismiss banner after 3 seconds.
                        let firedID = first.id
                        Task { @MainActor [weak self] in
                            try? await Task.sleep(for: .seconds(3))
                            guard let self else { return }
                            if triggeredAlert?.id == firedID { triggeredAlert = nil }
                        }
                    }
                }
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
