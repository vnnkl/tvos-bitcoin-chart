import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Fixture helpers

private func makeKline(
    openTime: Date = Date(timeIntervalSince1970: 0),
    close: Decimal = 50_000,
    isClosed: Bool = true
) -> Kline {
    Kline(
        openTime:  openTime,
        open:      close,
        high:      close + 100,
        low:       close - 100,
        close:     close,
        volume:    10,
        closeTime: openTime.addingTimeInterval(59),
        isClosed:  isClosed
    )
}

/// Generates `count` sequential 1-minute klines starting at epoch 0.
private func makeKlines(count: Int, isClosed: Bool = true) -> [Kline] {
    (0..<count).map { i in
        makeKline(
            openTime: Date(timeIntervalSince1970: Double(i) * 60),
            close:    Decimal(50_000 + i),
            isClosed: isClosed
        )
    }
}

// MARK: - Test Suite

@Suite("KlineStore")
struct KlineStoreTests {

    // MARK: loadHistorical

    @Test("loadHistorical stores the correct count and sorts ascending by openTime")
    func loadHistorical_countAndOrder() {
        let store = KlineStore()
        let klines = makeKlines(count: 10)
        // Shuffle to verify sort is applied
        store.loadHistorical(klines.shuffled())

        #expect(store.klines.count == 10)
        for i in 1..<store.klines.count {
            #expect(store.klines[i - 1].openTime <= store.klines[i].openTime)
        }
    }

    @Test("loadHistorical truncates to maxKlines")
    func loadHistorical_truncatesToMax() {
        let store = KlineStore(maxKlines: 5)
        store.loadHistorical(makeKlines(count: 10))
        #expect(store.klines.count == 5)
        // Should keep the most recent 5
        #expect(store.klines.first?.openTime == Date(timeIntervalSince1970: 5 * 60))
    }

    @Test("loadHistorical replaces existing data")
    func loadHistorical_replacesExisting() {
        let store = KlineStore()
        store.loadHistorical(makeKlines(count: 3))
        store.loadHistorical(makeKlines(count: 7))
        #expect(store.klines.count == 7)
    }

    // MARK: applyLive — closed candle

    @Test("applyLive: closed candle with same openTime replaces last element, count unchanged")
    func applyLive_closedSameOpenTime_replacesLast() {
        let store = KlineStore()
        let t0 = Date(timeIntervalSince1970: 0)
        store.loadHistorical(makeKlines(count: 5))

        // The 5th kline has openTime = 4 * 60
        let lastTime = Date(timeIntervalSince1970: 4 * 60)
        let closed = makeKline(openTime: lastTime, close: 99_999, isClosed: true)
        store.applyLive(closed)

        #expect(store.klines.count == 5)
        #expect(store.klines.last?.close == 99_999)
        #expect(store.klines.last?.isClosed == true)
    }

    @Test("applyLive: closed candle with new openTime appends, count increases")
    func applyLive_closedNewOpenTime_appends() {
        let store = KlineStore()
        store.loadHistorical(makeKlines(count: 5))

        let newTime = Date(timeIntervalSince1970: 5 * 60)  // next minute
        let newKline = makeKline(openTime: newTime, close: 55_000, isClosed: true)
        store.applyLive(newKline)

        #expect(store.klines.count == 6)
        #expect(store.klines.last?.openTime == newTime)
        #expect(store.klines.last?.close == 55_000)
    }

    // MARK: applyLive — open (in-progress) candle

    @Test("applyLive: open candle with same openTime updates close in-place")
    func applyLive_openSameOpenTime_updatesInPlace() {
        let store = KlineStore()
        store.loadHistorical(makeKlines(count: 3))

        let lastTime = Date(timeIntervalSince1970: 2 * 60)
        let update = makeKline(openTime: lastTime, close: 12_345, isClosed: false)
        store.applyLive(update)

        #expect(store.klines.count == 3)
        #expect(store.klines.last?.close == 12_345)
        #expect(store.klines.last?.isClosed == false)
    }

    @Test("applyLive: open candle with new openTime appends")
    func applyLive_openNewOpenTime_appends() {
        let store = KlineStore()
        store.loadHistorical(makeKlines(count: 3))

        let newTime = Date(timeIntervalSince1970: 3 * 60)
        let newOpen = makeKline(openTime: newTime, close: 48_000, isClosed: false)
        store.applyLive(newOpen)

        #expect(store.klines.count == 4)
        #expect(store.klines.last?.isClosed == false)
        #expect(store.klines.last?.openTime == newTime)
    }

    // MARK: Bound enforcement

    @Test("applyLive maintains maxKlines bound after repeated appends")
    func applyLive_boundEnforcement() {
        let store = KlineStore(maxKlines: 500)
        store.loadHistorical(makeKlines(count: 500))
        #expect(store.klines.count == 500)

        // Append 5 more closed candles — oldest 5 should be evicted
        let firstOldTime = store.klines.first!.openTime
        for i in 500..<505 {
            let t = Date(timeIntervalSince1970: Double(i) * 60)
            store.applyLive(makeKline(openTime: t, close: Decimal(60_000 + i), isClosed: true))
        }

        #expect(store.klines.count == 500)
        // The original oldest kline should have been evicted
        let newOldestTime = store.klines.first!.openTime
        #expect(newOldestTime > firstOldTime)
    }

    // MARK: Computed properties

    @Test("currentPrice returns last close")
    func currentPrice() {
        let store = KlineStore()
        store.loadHistorical(makeKlines(count: 3))
        // makeKlines(count:3) → closes are 50000, 50001, 50002
        #expect(store.currentPrice == Decimal(50_002))
    }

    @Test("currentPrice returns 0 when store is empty")
    func currentPrice_empty() {
        let store = KlineStore()
        #expect(store.currentPrice == 0)
    }

    @Test("priceChange24h returns 0 when store is empty")
    func priceChange24h_empty() {
        let store = KlineStore()
        #expect(store.priceChange24h == 0)
    }

    @Test("priceChange24h returns correct percentage")
    func priceChange24h_percentage() {
        let store = KlineStore()
        // ref kline: 24h before last, close = 50000
        let refTime = Date(timeIntervalSince1970: 0)
        let lastTime = Date(timeIntervalSince1970: 86_400) // exactly 24h later
        let refKline  = makeKline(openTime: refTime,  close: 50_000)
        let lastKline = makeKline(openTime: lastTime, close: 50_110)
        store.loadHistorical([refKline, lastKline])
        // (50110 - 50000) / 50000 * 100 = 110 / 50000 * 100 = 0.22
        #expect(store.priceChange24h == Decimal(string: "0.22")!)
    }
}
