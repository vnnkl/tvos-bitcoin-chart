import Foundation

/// Observable store that holds the most recent STRC API data.
///
/// Data is replaced wholesale on each successful fetch (no merge logic needed,
/// unlike `KlineStore`). Both properties start as empty/nil and are populated
/// by `STRCViewModel` once the first fetch completes.
///
/// **Inspection surfaces:**
/// - `tickerData` — `nil` before the first successful fetch, populated thereafter.
/// - `filings` — empty array before the first successful fetch.
@Observable
final class STRCStore: @unchecked Sendable {

    // MARK: - State

    /// The latest ticker snapshot from `/api/ticker-data`.
    private(set) var tickerData: STRCTickerResponse?

    /// All SEC filings from `/api/sec-filings`, in API-returned order.
    private(set) var filings: [SECFiling] = []

    // MARK: - Init

    init() {}

    // MARK: - Update

    /// Replace the stored ticker snapshot with a fresh response.
    func update(ticker: STRCTickerResponse) {
        tickerData = ticker
    }

    /// Replace the stored filings array with fresh data.
    func update(filings newFilings: [SECFiling]) {
        filings = newFilings
    }
}
