import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Helpers

private func makeTrade(id: Int, price: String = "42000.00", isBuyerMaker: Bool = false) -> AggTrade {
    let data = """
    {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":\(id),\
    "p":"\(price)","q":"0.1","f":\(id),"l":\(id),"T":1672531200000,"m":\(isBuyerMaker)}
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(AggTrade.self, from: data)
}

// MARK: - Append ordering

@Suite("TradeStore Append Ordering")
struct TradeStoreAppendTests {

    @Test("Append inserts most-recent trade at index 0")
    func appendInsertsAtFront() {
        let store = TradeStore()
        let first = makeTrade(id: 1)
        let second = makeTrade(id: 2)

        store.append(first)
        store.append(second)

        // Newest (id:2) must be at index 0 — most-recent-first ordering.
        #expect(store.trades.first?.aggregateTradeId == 2)
        #expect(store.trades.last?.aggregateTradeId == 1)
    }

    @Test("Append single trade results in count of 1")
    func appendSingleTradeHasCountOne() {
        let store = TradeStore()
        store.append(makeTrade(id: 1))
        #expect(store.trades.count == 1)
    }

    @Test("Three appended trades are in most-recent-first order")
    func threeTradesOrdering() {
        let store = TradeStore()
        store.append(makeTrade(id: 10))
        store.append(makeTrade(id: 20))
        store.append(makeTrade(id: 30))

        // Index 0 = most recent (30), index 2 = oldest (10).
        #expect(store.trades[0].aggregateTradeId == 30)
        #expect(store.trades[1].aggregateTradeId == 20)
        #expect(store.trades[2].aggregateTradeId == 10)
    }
}

// MARK: - Bounds enforcement

@Suite("TradeStore Bounds Enforcement")
struct TradeStoreBoundsTests {

    @Test("Default maxTrades is 100")
    func boundsDefaultMaxIs100() {
        let store = TradeStore()
        #expect(store.maxTrades == 100)
    }

    @Test("Count never exceeds maxTrades=100 after 150 appends")
    func boundsEnforcedAt100() {
        let store = TradeStore(maxTrades: 100)
        for id in 1...150 {
            store.append(makeTrade(id: id))
        }
        #expect(store.trades.count == 100, "Count must not exceed maxTrades=100")
    }

    @Test("Most recent trades retained after overflow trim")
    func boundsMostRecentRetainedAfterTrim() {
        // Append 150 trades (ids 1..150). The newest 100 (ids 51..150) must survive.
        let store = TradeStore(maxTrades: 100)
        for id in 1...150 {
            store.append(makeTrade(id: id))
        }
        // trades[0] should be the last appended (id 150 — most recent).
        #expect(store.trades[0].aggregateTradeId == 150)
        // trades[99] should be id 51 (oldest retained).
        #expect(store.trades[99].aggregateTradeId == 51)
    }

    @Test("Oldest trade evicted on overflow")
    func boundsOldestDroppedOnOverflow() {
        let store = TradeStore(maxTrades: 3)
        store.append(makeTrade(id: 1))
        store.append(makeTrade(id: 2))
        store.append(makeTrade(id: 3))
        store.append(makeTrade(id: 4)) // overflow: id 1 should be evicted

        #expect(store.trades.count == 3)
        #expect(!store.trades.contains { $0.aggregateTradeId == 1 }, "Oldest trade must be evicted")
        #expect(store.trades[0].aggregateTradeId == 4, "Newest must be at front")
    }

    @Test("Custom maxTrades is respected")
    func customMaxTrades() {
        let store = TradeStore(maxTrades: 5)
        #expect(store.maxTrades == 5)
        for id in 1...10 {
            store.append(makeTrade(id: id))
        }
        #expect(store.trades.count == 5)
    }
}

// MARK: - Clear

@Suite("TradeStore Clear")
struct TradeStoreClearTests {

    @Test("Clear empties the store")
    func clearEmptiesStore() {
        let store = TradeStore()
        for id in 1...10 {
            store.append(makeTrade(id: id))
        }
        #expect(!store.trades.isEmpty)
        store.clear()
        #expect(store.trades.isEmpty)
    }

    @Test("Clear then append works correctly")
    func clearThenAppend() {
        let store = TradeStore()
        store.append(makeTrade(id: 1))
        store.clear()
        store.append(makeTrade(id: 99))
        #expect(store.trades.count == 1)
        #expect(store.trades[0].aggregateTradeId == 99)
    }
}

// MARK: - Initial state

@Suite("TradeStore Initial State")
struct TradeStoreInitTests {

    @Test("Store is empty on init")
    func initialStateEmpty() {
        let store = TradeStore()
        #expect(store.trades.isEmpty)
    }
}
