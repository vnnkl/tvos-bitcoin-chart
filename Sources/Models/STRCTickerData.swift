import Foundation

// MARK: - Top-Level Response

/// Top-level response from `GET https://strc.live/api/ticker-data`.
///
/// The response contains a snapshot of all tracked tickers (keyed by symbol),
/// current BTC price, market hours status, and a freshness timestamp.
struct STRCTickerResponse: Codable, Sendable {
    let success: Bool
    /// ISO 8601 timestamp of when the data was last updated on the server.
    let updated: String
    /// Current BTC/USD price at the time of the snapshot.
    let btcPrice: Double
    let marketStatus: MarketStatus
    /// Dictionary keyed by ticker symbol (e.g. `"STRC"`, `"SATA"`).
    let tickers: [String: STRCTicker]
}

// MARK: - Market Status

/// Current market session state.
struct MarketStatus: Codable, Sendable {
    /// `"open"` | `"closed"` | `"holiday"` etc.
    let market: String
    let afterHours: Bool
    let earlyHours: Bool
}

// MARK: - Per-Ticker Data

/// Full data payload for a single ticker symbol (e.g. STRC or SATA).
struct STRCTicker: Codable, Sendable {
    let ipoDate: String
    let closePrice: Double
    let previousClose: Double
    let extendedHoursPrice: Double?
    let extendedHoursChange: Double?
    let extendedHoursChangePercent: Double?
    let latest: LatestPrice
    let summary: TickerSummary
    let dividends: DividendInfo
    let btcCorrelation: BTCCorrelation?
    /// Daily OHLCV history — large array, decoded but only partially displayed.
    let history: [PriceBar]?
    // `intraday` and `volumeProfiles` are intentionally omitted from the model —
    // they are large dicts (keyed by date string) we don't display on the dashboard.
    // Swift Codable simply ignores unknown keys when `keyDecodingStrategy` is not set.
}

// MARK: - Latest Price Bar

/// The most-recent price bar for a ticker.
struct LatestPrice: Codable, Sendable {
    let date: String
    let close: Double
    let high: Double
    let low: Double
    let volume: Int
    /// `"regular"` | `"extended"` | `"pre"` etc.
    let source: String
}

// MARK: - Ticker Summary (Dividend / ATM Info)

/// Dividend and yield summary for a ticker.
struct TickerSummary: Codable, Sendable {
    let annualizedDividend: Double?
    let currentYield: Double?
    /// ISO date string, e.g. `"2026-03-20"`.
    let exDividendDate: String?
    let rateSource: String?
}

// MARK: - Dividend Info

/// Container for current and historical dividend records.
struct DividendInfo: Codable, Sendable {
    let current: DividendRecord?
    let history: [DividendRecord]?
}

/// A single dividend event record.
struct DividendRecord: Codable, Sendable {
    let exDate: String
    let payDate: String
    let amount: Double
    let annualizedRate: Double?
    let recordDate: String?
    let declarationDate: String?
}

// MARK: - BTC Correlation

/// BTC correlation statistics for a ticker.
struct BTCCorrelation: Codable, Sendable {
    let current: Double
    let windowDays: Int
    // `history` array omitted — not displayed on dashboard.
}

// MARK: - Daily Price Bar

/// A daily OHLCV bar from a ticker's historical series.
struct PriceBar: Codable, Sendable {
    let date: String
    let close: Double
    let high: Double
    let low: Double
    let volume: Int
    let source: String
}
