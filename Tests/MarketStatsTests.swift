import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Fixture helpers

private func makeKline(
    openTime: Date,
    high: Decimal,
    low: Decimal,
    close: Decimal = 50_000,
    volume: Decimal = 10
) -> Kline {
    Kline(
        openTime:  openTime,
        open:      close,
        high:      high,
        low:       low,
        close:     close,
        volume:    volume,
        closeTime: openTime.addingTimeInterval(59),
        isClosed:  true
    )
}

private func makeTrade(id: Int, quantity: Decimal, isBuy: Bool) -> AggTrade {
    AggTrade(
        aggregateTradeId: id,
        price:            50_000,
        quantity:         quantity,
        time:             Date(timeIntervalSince1970: Double(id)),
        isBuyerMaker:     !isBuy
    )
}

// MARK: - KlineStore 24h stats

@Suite("KlineStore 24h stats")
struct KlineStoreStats24hTests {

    @Test("stats24h is nil when store is empty")
    func stats_empty() {
        let store = KlineStore()
        #expect(store.stats24h == nil)
    }

    @Test("stats24h aggregates high, low, and volume across all klines in window")
    func stats_aggregates() {
        let store = KlineStore()
        let t0 = Date(timeIntervalSince1970: 0)
        store.loadHistorical([
            makeKline(openTime: t0,                          high: 50_500, low: 49_500, volume: 10),
            makeKline(openTime: t0.addingTimeInterval(60),   high: 51_000, low: 49_000, volume: 5),
            makeKline(openTime: t0.addingTimeInterval(120),  high: 50_200, low: 49_800, volume: 2.5)
        ])

        let stats = store.stats24h
        #expect(stats?.high == 51_000)
        #expect(stats?.low == 49_000)
        #expect(stats?.volume == Decimal(string: "17.5")!)
    }

    @Test("stats24h excludes klines older than 24h before the newest candle")
    func stats_windowExcludesOld() {
        let store = KlineStore()
        let old  = Date(timeIntervalSince1970: 0)
        let last = Date(timeIntervalSince1970: 86_400 + 60)   // 24h + 1min later
        store.loadHistorical([
            makeKline(openTime: old,  high: 99_000, low: 1_000, volume: 100),
            makeKline(openTime: last, high: 50_500, low: 49_500, volume: 10)
        ])

        let stats = store.stats24h
        #expect(stats?.high == 50_500)
        #expect(stats?.low == 49_500)
        #expect(stats?.volume == 10)
    }
}

// MARK: - Order book imbalance

@Suite("OrderBookSnapshot imbalance")
struct OrderBookImbalanceTests {

    @Test("bidImbalance is 0.5 when both sides are empty")
    func imbalance_emptyBook() {
        let snapshot = OrderBookSnapshot(lastUpdateId: 1, bids: [], asks: [])
        #expect(snapshot.bidImbalance == 0.5)
    }

    @Test("bidImbalance is 1 when only bids have quantity")
    func imbalance_allBids() {
        let snapshot = OrderBookSnapshot(
            lastUpdateId: 1,
            bids: [PriceLevel(price: 50_000, quantity: 2)],
            asks: []
        )
        #expect(snapshot.bidImbalance == 1.0)
    }

    @Test("bidImbalance reflects the bid share of total quantity")
    func imbalance_ratio() {
        let snapshot = OrderBookSnapshot(
            lastUpdateId: 1,
            bids: [
                PriceLevel(price: 49_999, quantity: 1),
                PriceLevel(price: 49_998, quantity: 2)
            ],
            asks: [
                PriceLevel(price: 50_001, quantity: 1)
            ]
        )
        // bids = 3, asks = 1 → 3 / 4 = 0.75
        #expect(abs(snapshot.bidImbalance - 0.75) < 0.000_001)
    }
}

// MARK: - Compact number formatting

@MainActor
@Suite("AppFormatters.compact")
struct CompactFormatterTests {

    @Test("formats sub-thousand values with one fraction digit")
    func compact_small() {
        #expect(AppFormatters.compact(Decimal(831.42)) == "831.4")
    }

    @Test("formats thousands with K suffix")
    func compact_thousands() {
        #expect(AppFormatters.compact(Decimal(12_400)) == "12.4K")
        #expect(AppFormatters.compact(Decimal(1_280)) == "1.28K")
    }

    @Test("formats millions and billions")
    func compact_millionsBillions() {
        #expect(AppFormatters.compact(Decimal(1_280_000)) == "1.28M")
        #expect(AppFormatters.compact(Decimal(2_500_000_000)) == "2.50B")
    }

    @Test("preserves negative sign")
    func compact_negative() {
        #expect(AppFormatters.compact(Decimal(-12_400)) == "-12.4K")
    }
}

// MARK: - Trade flow

@Suite("TradeStore buy pressure")
struct TradeStoreBuyPressureTests {

    @Test("buyVolumeRatio is 0.5 when no trades are present")
    func buyRatio_empty() {
        let store = TradeStore()
        #expect(store.buyVolumeRatio() == 0.5)
    }

    @Test("buyVolumeRatio is 1 when all trades are buys")
    func buyRatio_allBuys() {
        let store = TradeStore()
        store.append(makeTrade(id: 1, quantity: 1, isBuy: true))
        store.append(makeTrade(id: 2, quantity: 3, isBuy: true))
        #expect(store.buyVolumeRatio() == 1.0)
    }

    @Test("buyVolumeRatio weights by quantity, not trade count")
    func buyRatio_weightedByQuantity() {
        let store = TradeStore()
        store.append(makeTrade(id: 1, quantity: 3, isBuy: true))
        store.append(makeTrade(id: 2, quantity: 1, isBuy: false))
        // buys = 3 of 4 total → 0.75
        #expect(abs(store.buyVolumeRatio() - 0.75) < 0.000_001)
    }

    @Test("buyVolumeRatio only considers the most recent `window` trades")
    func buyRatio_windowLimit() {
        let store = TradeStore()
        // Oldest: one huge sell that must fall outside the window.
        store.append(makeTrade(id: 1, quantity: 100, isBuy: false))
        for i in 2...4 {
            store.append(makeTrade(id: i, quantity: 1, isBuy: true))
        }
        // Window of 3 → only the three buys count.
        #expect(store.buyVolumeRatio(window: 3) == 1.0)
    }
}
