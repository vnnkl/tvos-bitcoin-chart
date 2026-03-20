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
/// The `btcPurchased` field is always `null` in the raw API response.
/// Use the `estimatedBTCPurchased` computed property to derive the value
/// from `netProceeds / avgBtcPrice`.
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
    /// Always `null` in the API — use `estimatedBTCPurchased` instead.
    let btcPurchased: Int?
    /// Average BTC price in whole dollars used to calculate BTC acquisitions.
    let avgBtcPrice: Int
    /// Offering type, e.g. `"atm"`, `"ipo"`, `"follow_on"`.
    let offeringType: String

    // MARK: - Derived

    /// Estimated BTC purchased, derived as `netProceeds / avgBtcPrice`.
    ///
    /// The raw API always returns `null` for `btcPurchased`. The strc.live
    /// dashboard derives this value locally — we match that calculation here.
    var estimatedBTCPurchased: Double {
        guard avgBtcPrice > 0 else { return 0 }
        return Double(netProceeds) / Double(avgBtcPrice)
    }
}
