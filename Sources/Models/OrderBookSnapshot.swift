import Foundation

/// Minimal stub for an order book snapshot.
/// Full implementation arrives in S02 (depth heatmap slice).
struct OrderBookSnapshot: Sendable {
    let lastUpdateId: Int
    let bids: [(price: Decimal, quantity: Decimal)]
    let asks: [(price: Decimal, quantity: Decimal)]
}
