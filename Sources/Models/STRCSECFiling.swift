import Foundation

// MARK: - Top-Level Response

/// Top-level response from `GET https://strc.live/api/sec-filings`.
struct STRCFilingsResponse: Codable, Sendable {
    let success: Bool
    let filings: [SECFiling]
}

// MARK: - Single Filing Record

/// A single SEC 8-K ATM offering record.
///
/// The `btcPurchased` field may be `null`, `0`, or an actual (possibly
/// fractional) BTC amount like `381.61` — the API originally always sent
/// `null` but now reports real values for some rows. Use the
/// `estimatedBTCPurchased` computed property, which prefers the reported
/// value and falls back to deriving it from `netProceeds / avgBtcPrice`.
struct SECFiling: Codable, Sendable {
    /// Ticker symbol, e.g. `"STRC"` or `"SATA"`.
    let ticker: String
    /// ISO date string the 8-K was filed, e.g. `"2026-03-16"`.
    let filedDate: String
    /// Link to the SEC filing document.
    let url: String
    /// Human-readable period description, e.g. `"Mar 8 - Mar 14"`.
    let period: String?
    /// ISO date string for the start of the offering period.
    let periodStart: String?
    /// ISO date string for the end of the offering period.
    let periodEnd: String?
    /// Number of shares sold in this offering.
    let sharesSold: Int
    /// Net proceeds from the offering in whole dollars (not cents).
    let netProceeds: Int
    /// BTC purchased as reported by the API — often `null` or `0`, sometimes
    /// a fractional amount. Prefer `estimatedBTCPurchased` for display.
    let btcPurchased: Double?
    /// Average BTC price in dollars used to calculate BTC acquisitions.
    /// Fractional in some rows — must not be `Int` or the whole feed
    /// fails to decode.
    let avgBtcPrice: Double
    /// Offering type, e.g. `"atm"`, `"ipo"`, `"follow_on"`, `"btc_update"`.
    let offeringType: String

    // MARK: - Derived

    /// BTC purchased for this filing: the API-reported value when present and
    /// positive, otherwise derived as `netProceeds / avgBtcPrice` (matching
    /// the strc.live dashboard's local calculation).
    var estimatedBTCPurchased: Double {
        if let btcPurchased, btcPurchased > 0 { return btcPurchased }
        guard avgBtcPrice > 0 else { return 0 }
        return Double(netProceeds) / avgBtcPrice
    }
}
