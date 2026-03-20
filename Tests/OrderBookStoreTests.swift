import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Fixture helpers

private func makeLevel(price: Decimal, quantity: Decimal = 1) -> PriceLevel {
    PriceLevel(price: price, quantity: quantity)
}

private func makeSnapshot(
    lastUpdateId: Int = 1,
    bids: [PriceLevel] = [makeLevel(price: 100)],
    asks: [PriceLevel] = [makeLevel(price: 101)],
    timestamp: Date = Date()
) -> OrderBookSnapshot {
    OrderBookSnapshot(lastUpdateId: lastUpdateId, bids: bids, asks: asks, timestamp: timestamp)
}

/// Builds a sequence of snapshots with predictable timestamps (epoch 0, 1, 2, …).
private func makeSnapshots(count: Int) -> [OrderBookSnapshot] {
    (0..<count).map { i in
        makeSnapshot(
            lastUpdateId: i,
            timestamp: Date(timeIntervalSince1970: Double(i))
        )
    }
}

// MARK: - Test Suite

@Suite("OrderBookStore")
struct OrderBookStoreTests {

    // MARK: append — within bounds

    @Test("append within bounds does not drop any snapshots")
    func append_withinBounds() {
        let store = OrderBookStore(maxSnapshots: 10)
        for snapshot in makeSnapshots(count: 5) {
            store.append(snapshot)
        }
        #expect(store.snapshots.count == 5)
    }

    // MARK: append — exceeding bounds (ring buffer)

    @Test("append exceeding maxSnapshots drops oldest entries")
    func append_exceedingBoundsDropsOldest() {
        let store = OrderBookStore(maxSnapshots: 3)
        let all = makeSnapshots(count: 5)
        for snapshot in all {
            store.append(snapshot)
        }

        // Should retain only the 3 most recent (indices 2, 3, 4)
        #expect(store.snapshots.count == 3)
        // The oldest two snapshots (timestamps 0 and 1) should be gone
        let expectedOldestTimestamp = Date(timeIntervalSince1970: 2)
        #expect(store.snapshots.first?.timestamp == expectedOldestTimestamp)
    }

    // MARK: priceRange — single snapshot

    @Test("priceRange for single snapshot uses min bid and max ask")
    func priceRange_singleSnapshot() {
        let store = OrderBookStore()
        let snapshot = makeSnapshot(
            bids: [makeLevel(price: 100), makeLevel(price: 99)],
            asks: [makeLevel(price: 101), makeLevel(price: 102)]
        )
        store.append(snapshot)

        let range = store.priceRange
        #expect(range.min == 99)
        #expect(range.max == 102)
    }

    // MARK: priceRange — across multiple snapshots

    @Test("priceRange across multiple snapshots uses global min bid and max ask")
    func priceRange_multipleSnapshots() {
        let store = OrderBookStore()

        // First snapshot: bid 95, ask 105
        store.append(makeSnapshot(
            lastUpdateId: 1,
            bids: [makeLevel(price: 95)],
            asks: [makeLevel(price: 105)]
        ))

        // Second snapshot: bid 98, ask 110 (higher max, higher min bid — global min stays 95)
        store.append(makeSnapshot(
            lastUpdateId: 2,
            bids: [makeLevel(price: 98)],
            asks: [makeLevel(price: 110)]
        ))

        let range = store.priceRange
        #expect(range.min == 95)
        #expect(range.max == 110)
    }

    // MARK: priceRange — empty store

    @Test("priceRange returns (0, 0) when store is empty")
    func priceRange_emptyStore() {
        let store = OrderBookStore()
        let range = store.priceRange
        #expect(range.min == 0)
        #expect(range.max == 0)
    }

    // MARK: clear

    @Test("clear resets snapshots to empty")
    func clear_resetsToEmpty() {
        let store = OrderBookStore()
        for snapshot in makeSnapshots(count: 5) {
            store.append(snapshot)
        }
        #expect(store.snapshots.isEmpty == false)

        store.clear()

        #expect(store.snapshots.isEmpty == true)
        // priceRange should also return (0, 0) after clear
        let range = store.priceRange
        #expect(range.min == 0)
        #expect(range.max == 0)
    }

    // MARK: default maxSnapshots

    @Test("default maxSnapshots is 500 matching KlineStore capacity")
    func defaultMaxSnapshots() {
        let store = OrderBookStore()
        #expect(store.maxSnapshots == 500)
    }
}
