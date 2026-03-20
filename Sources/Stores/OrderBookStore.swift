import Foundation

/// Observable store that holds a bounded, time-ordered ring buffer of `OrderBookSnapshot` values.
///
/// Each snapshot represents one 100ms depth message from Binance.
/// The heatmap renderer reads this store to map liquidity across time (X-axis)
/// and price (Y-axis), using one snapshot per column.
///
/// The array never exceeds `maxSnapshots` — oldest snapshots are dropped from the front.
@Observable
final class OrderBookStore: @unchecked Sendable {

    // MARK: - Configuration

    let maxSnapshots: Int

    // MARK: - State

    private(set) var snapshots: [OrderBookSnapshot] = []

    // MARK: - Init

    init(maxSnapshots: Int = 500) {
        self.maxSnapshots = maxSnapshots
    }

    // MARK: - Computed

    /// The global price range across all stored snapshots, used for Y-axis mapping.
    ///
    /// - `min`: the lowest bid price seen in any snapshot
    /// - `max`: the highest ask price seen in any snapshot
    ///
    /// Returns `(0, 0)` when the store is empty.
    var priceRange: (min: Decimal, max: Decimal) {
        guard !snapshots.isEmpty else { return (0, 0) }

        var globalMin = Decimal.greatestFiniteMagnitude
        var globalMax = Decimal(0)

        for snapshot in snapshots {
            for bid in snapshot.bids {
                if bid.price < globalMin { globalMin = bid.price }
            }
            for ask in snapshot.asks {
                if ask.price > globalMax { globalMax = ask.price }
            }
        }

        // Guard against snapshots that contain no bids or no asks
        if globalMin == Decimal.greatestFiniteMagnitude { globalMin = 0 }

        return (globalMin, globalMax)
    }

    // MARK: - Data ingestion

    /// Appends a new depth snapshot, evicting oldest entries to stay within `maxSnapshots`.
    func append(_ snapshot: OrderBookSnapshot) {
        snapshots.append(snapshot)
        if snapshots.count > maxSnapshots {
            snapshots.removeFirst(snapshots.count - maxSnapshots)
        }
    }

    /// Resets the store to empty — called when the user switches symbol or interval.
    func clear() {
        snapshots = []
    }
}
