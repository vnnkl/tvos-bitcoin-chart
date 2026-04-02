import Foundation
import Testing
@testable import BitcoinTerminal

private func regimeKline(index: Int, close: Decimal, spread: Decimal = 1) -> Kline {
    Kline(
        openTime: Date(timeIntervalSince1970: Double(index) * 60),
        open: close - spread / 2,
        high: close + spread,
        low: close - spread,
        close: close,
        volume: 10,
        closeTime: Date(timeIntervalSince1970: Double(index) * 60 + 59),
        isClosed: true
    )
}

private func regimeTrade(id: Int, quantity: Decimal, isBuy: Bool) -> AggTrade {
    AggTrade(
        aggregateTradeId: id,
        price: 50_000,
        quantity: quantity,
        time: Date(timeIntervalSince1970: Double(id)),
        isBuyerMaker: !isBuy
    )
}

private func regimeSnapshot(bidQuantity: Decimal, askQuantity: Decimal) -> OrderBookSnapshot {
    OrderBookSnapshot(
        lastUpdateId: 1,
        bids: (0..<5).map { offset in
            PriceLevel(price: Decimal(50_000 - offset), quantity: bidQuantity)
        },
        asks: (0..<5).map { offset in
            PriceLevel(price: Decimal(50_001 + offset), quantity: askQuantity)
        }
    )
}

@Suite("Market Regime")
struct MarketRegimeTests {

    @Test("Warm-up state appears before enough candles accumulate")
    func warmingUpState() {
        let klines = (0..<10).map { regimeKline(index: $0, close: Decimal(50_000 + $0)) }

        let state = marketRegimeState(klines: klines, trades: [], snapshot: nil)

        #expect(state.kind == .warmingUp)
    }

    @Test("Bullish structure with bid support reads as trend up")
    func trendUpState() {
        let klines = (0..<60).map { index in
            regimeKline(index: index, close: Decimal(50_000 + index * 18), spread: 18)
        }
        let trades = (0..<20).map { regimeTrade(id: $0, quantity: 4, isBuy: true) }
            + (20..<24).map { regimeTrade(id: $0, quantity: 1, isBuy: false) }

        let state = marketRegimeState(
            klines: klines,
            trades: trades,
            snapshot: regimeSnapshot(bidQuantity: 9, askQuantity: 3)
        )

        #expect(state.kind == .trendUpBidsHolding)
    }

    @Test("Bearish structure with heavy asks reads as trend down")
    func trendDownState() {
        let klines = (0..<60).map { index in
            regimeKline(index: index, close: Decimal(60_000 - index * 20), spread: 20)
        }
        let trades = (0..<20).map { regimeTrade(id: $0, quantity: 4, isBuy: false) }
            + (20..<24).map { regimeTrade(id: $0, quantity: 1, isBuy: true) }

        let state = marketRegimeState(
            klines: klines,
            trades: trades,
            snapshot: regimeSnapshot(bidQuantity: 3, askQuantity: 9)
        )

        #expect(state.kind == .trendDownOffersHeavy)
    }

    @Test("Flat low-range tape reads as compression")
    func compressionState() {
        let closes: [Decimal] = [
            50_000, 50_002, 50_001, 50_003, 50_002, 50_001, 50_003, 50_002,
            50_001, 50_003, 50_002, 50_001, 50_003, 50_002, 50_001, 50_003,
            50_002, 50_001, 50_003, 50_002, 50_001, 50_003, 50_002, 50_001
        ]
        let klines = closes.enumerated().map { regimeKline(index: $0.offset, close: $0.element, spread: 1) }
        let trades = (0..<12).map { regimeTrade(id: $0, quantity: 2, isBuy: true) }
            + (12..<24).map { regimeTrade(id: $0, quantity: 2, isBuy: false) }

        let state = marketRegimeState(
            klines: klines,
            trades: trades,
            snapshot: regimeSnapshot(bidQuantity: 5, askQuantity: 5)
        )

        #expect(state.kind == .rangeCompression)
    }

    @Test("Only real regime shifts announce")
    func transitionRules() {
        let previous = MarketRegimeState(kind: .balancedFlow, title: "Balanced Flow", summary: "Mixed")
        let next = MarketRegimeState(kind: .trendUpBidsHolding, title: "Trend Up", summary: "Up")

        #expect(shouldAnnounceRegimeTransition(previous: .warmingUp, next: next) == false)
        #expect(shouldAnnounceRegimeTransition(previous: previous, next: previous) == false)
        #expect(shouldAnnounceRegimeTransition(previous: previous, next: next) == true)
    }
}
