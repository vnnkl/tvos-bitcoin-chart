import Foundation
import OSLog

private let logger = Logger(subsystem: "com.bitcointerminal.strc", category: "STRCViewModel")

/// Orchestrates fetching and periodic refresh of STRC data from `strc.live`.
///
/// - Fetches both `/api/ticker-data` and `/api/sec-filings` concurrently on `start()`.
/// - Auto-refreshes every 60 seconds while the scene is active.
/// - Exposes `isLoading`, `error`, and `lastUpdated` for the view layer to observe.
///
/// **Lifecycle contract:**
/// - Call `start()` when the scene becomes `.active` (wired in `ContentView`).
/// - Call `stop()` when the scene becomes `.background` or `.inactive`.
///
/// **Observability:**
/// - `isLoading` — `true` while a fetch is in flight.
/// - `error` — non-nil when the last fetch attempt failed.
/// - `lastUpdated` — `nil` until the first successful fetch.
/// - `log stream --predicate 'subsystem == "com.bitcointerminal.strc"'` for runtime logs.
@Observable
@MainActor
final class STRCViewModel {

    // MARK: - Public state (observed by views)

    let store = STRCStore()
    var isLoading = false
    var error: Error?
    var lastUpdated: Date?

    // MARK: - Derived from store

    /// Current STRC ATM status label: "Active" (price ≥ $100 par) or "Standby".
    var atmStatus: String {
        isATMActive ? "Active" : "Standby"
    }

    /// `true` when STRC close price is at or above the $100 par value.
    var isATMActive: Bool {
        (store.tickerData?.tickers["STRC"]?.closePrice ?? 0) >= 100
    }

    // MARK: - Private

    private let service: STRCService
    private var refreshTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?

    // MARK: - Init

    init(service: STRCService = STRCService()) {
        self.service = service
    }

    // MARK: - Lifecycle

    /// Begin data fetching and start the 60-second auto-refresh loop.
    ///
    /// Safe to call multiple times — cancels any existing tasks first.
    func start() {
        logger.info("STRCViewModel.start()")
        // Cancel existing tasks before starting fresh
        refreshTask?.cancel()
        autoRefreshTask?.cancel()

        // Kick off an immediate fetch then loop every 60 s
        autoRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.fetch()
                // Sleep 60 s before next refresh; cancellation wakes immediately
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    /// Stop all background tasks and clear in-flight state.
    func stop() {
        logger.info("STRCViewModel.stop()")
        refreshTask?.cancel()
        refreshTask = nil
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    // MARK: - Private: data fetch

    /// Fetch both endpoints concurrently and update the store on success.
    private func fetch() async {
        guard !Task.isCancelled else { return }
        logger.info("Fetching STRC data (ticker + filings)")
        isLoading = true
        error = nil

        do {
            // Run both network requests in parallel via a task group
            async let tickerFetch = service.fetchTickerData()
            async let filingsFetch = service.fetchFilings()

            let (ticker, filingsResponse) = try await (tickerFetch, filingsFetch)

            store.update(ticker: ticker)
            store.update(filings: filingsResponse.filings)
            lastUpdated = Date()
            logger.info("STRC data updated — \(filingsResponse.filings.count) filing(s), btcPrice: \(ticker.btcPrice)")
        } catch {
            logger.error("STRC fetch failed: \(error.localizedDescription)")
            self.error = error
        }

        isLoading = false
    }
}
