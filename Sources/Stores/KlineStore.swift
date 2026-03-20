import Foundation

/// Observable store that holds a bounded, time-ordered array of `Kline` values.
///
/// Two data paths feed the store:
/// - **Historical** (`loadHistorical`): replaces the entire array from REST data.
/// - **Live** (`applyLive`): merges a single WebSocket update, distinguishing between
///   an open (still-forming) candle and a closed (completed) candle.
///
/// The array never exceeds `maxKlines` — oldest candles are dropped from the front.
@Observable
final class KlineStore: @unchecked Sendable {

    // MARK: - Configuration

    let maxKlines: Int

    // MARK: - State

    private(set) var klines: [Kline] = []

    // MARK: - Init

    init(maxKlines: Int = 500) {
        self.maxKlines = maxKlines
    }

    // MARK: - Computed

    /// The most recent closing price, or `0` when no data is loaded.
    var currentPrice: Decimal {
        klines.last?.close ?? 0
    }

    /// Price change vs the kline whose `openTime` is ≥ 24 h ago.
    /// Returns `0` when fewer than two candles are present.
    var priceChange24h: Decimal {
        guard let last = klines.last else { return 0 }
        let cutoff = last.openTime - 86_400          // 24 h in seconds
        let reference = klines.first(where: { $0.openTime >= cutoff }) ?? klines.first
        guard let ref = reference, ref.openTime != last.openTime else { return 0 }
        guard ref.close != 0 else { return 0 }
        return (last.close - ref.close) / ref.close * 100
    }

    // MARK: - Data ingestion

    /// Replace the store with sorted, bounded historical data.
    func loadHistorical(_ newKlines: [Kline]) {
        let sorted = newKlines.sorted { $0.openTime < $1.openTime }
        klines = Array(sorted.suffix(maxKlines))
    }

    /// Merge a single live kline from the WebSocket stream.
    ///
    /// - If the candle's `openTime` matches the last stored kline, update/replace it.
    /// - Otherwise, append it (new candle started).
    /// - After any append, trim oldest candles to stay within `maxKlines`.
    func applyLive(_ kline: Kline) {
        if klines.last?.openTime == kline.openTime {
            // Update the current (last) candle in place — handles both open updates
            // and the final closed version arriving after an open one.
            klines[klines.count - 1] = kline
        } else {
            klines.append(kline)
            if klines.count > maxKlines {
                klines.removeFirst(klines.count - maxKlines)
            }
        }
    }
}
