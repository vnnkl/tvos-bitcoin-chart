import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Protocol Conformance & Connection State

@Suite("StubExchangeService Protocol Conformance")
struct StubExchangeServiceConformanceTests {

    @Test("connectionState is always .connected")
    func connectionStateIsConnected() {
        let sut = StubExchangeService()
        #expect(sut.connectionState == .connected)
    }

    @Test("disconnect() does not crash")
    func disconnectIsNoOp() {
        let sut = StubExchangeService()
        sut.disconnect()   // Should be a no-op; just verify no crash.
        #expect(sut.connectionState == .connected)
    }
}

// MARK: - fetchKlines

@Suite("StubExchangeService fetchKlines")
struct StubExchangeServiceKlineTests {

    @Test("fetchKlines returns non-empty array")
    func fetchKlinesReturnsNonEmpty() async throws {
        let sut = StubExchangeService()
        let klines = try await sut.fetchKlines(symbol: "BTCUSDT", interval: "1m", limit: 500)
        #expect(!klines.isEmpty)
    }

    @Test("fetchKlines returns exactly 5 fixture klines")
    func fetchKlinesReturnsExactlyFive() async throws {
        let sut = StubExchangeService()
        let klines = try await sut.fetchKlines(symbol: "BTCUSDT", interval: "1m", limit: 500)
        #expect(klines.count == 5)
    }

    @Test("fetchKlines fixture klines have correct open price")
    func fetchKlinesFixtureOpenPrice() async throws {
        let sut = StubExchangeService()
        let klines = try await sut.fetchKlines(symbol: "BTCUSDT", interval: "1m", limit: 500)
        #expect(klines[0].open == 42000)
    }

    @Test("fetchKlines fixture klines have correct close price")
    func fetchKlinesFixtureClosePrice() async throws {
        let sut = StubExchangeService()
        let klines = try await sut.fetchKlines(symbol: "BTCUSDT", interval: "1m", limit: 500)
        #expect(klines[0].close == 42200)
    }

    @Test("fetchKlines fixture klines are all closed")
    func fetchKlinesFixtureAreAllClosed() async throws {
        let sut = StubExchangeService()
        let klines = try await sut.fetchKlines(symbol: "BTCUSDT", interval: "1m", limit: 500)
        #expect(klines.allSatisfy { $0.isClosed })
    }

    @Test("fetchKlines ignores symbol and interval parameters (returns same fixture)")
    func fetchKlinesIgnoresParameters() async throws {
        let sut = StubExchangeService()
        let btc = try await sut.fetchKlines(symbol: "BTCUSDT", interval: "1h", limit: 100)
        let eth = try await sut.fetchKlines(symbol: "ETHUSDT", interval: "1d", limit: 10)
        #expect(btc.count == eth.count)
    }
}

// MARK: - subscribeKlines

@Suite("StubExchangeService subscribeKlines")
struct StubExchangeServiceSubscribeKlineTests {

    @Test("subscribeKlines yields at least one kline")
    func subscribeKlinesYieldsOneKline() async throws {
        let sut = StubExchangeService()
        var received: [Kline] = []
        for try await kline in sut.subscribeKlines(symbol: "BTCUSDT", interval: "1m") {
            received.append(kline)
        }
        #expect(!received.isEmpty)
    }

    @Test("subscribeKlines yields fixture kline with correct close price")
    func subscribeKlinesFixturePrice() async throws {
        let sut = StubExchangeService()
        var first: Kline?
        for try await kline in sut.subscribeKlines(symbol: "BTCUSDT", interval: "1m") {
            first = kline
            break
        }
        #expect(first?.close == 42200)
    }
}

// MARK: - subscribeOrderBook

@Suite("StubExchangeService subscribeOrderBook")
struct StubExchangeServiceOrderBookTests {

    @Test("subscribeOrderBook yields at least one snapshot")
    func subscribeOrderBookYieldsOneSnapshot() async throws {
        let sut = StubExchangeService()
        var received: [OrderBookSnapshot] = []
        for try await snapshot in sut.subscribeOrderBook(symbol: "BTCUSDT") {
            received.append(snapshot)
        }
        #expect(!received.isEmpty)
    }

    @Test("subscribeOrderBook fixture snapshot has bids and asks")
    func subscribeOrderBookFixtureHasBidsAndAsks() async throws {
        let sut = StubExchangeService()
        var first: OrderBookSnapshot?
        for try await snapshot in sut.subscribeOrderBook(symbol: "BTCUSDT") {
            first = snapshot
            break
        }
        #expect(first != nil)
        #expect(!(first?.bids.isEmpty ?? true))
        #expect(!(first?.asks.isEmpty ?? true))
    }
}

// MARK: - subscribeTrades

@Suite("StubExchangeService subscribeTrades")
struct StubExchangeServiceTradeTests {

    @Test("subscribeTrades yields at least one trade")
    func subscribeTradesYieldsOneTrade() async throws {
        let sut = StubExchangeService()
        var received: [AggTrade] = []
        for try await trade in sut.subscribeTrades(symbol: "BTCUSDT") {
            received.append(trade)
        }
        #expect(!received.isEmpty)
    }

    @Test("subscribeTrades fixture trade is a BUY")
    func subscribeTradesFixtureIsBuy() async throws {
        let sut = StubExchangeService()
        var first: AggTrade?
        for try await trade in sut.subscribeTrades(symbol: "BTCUSDT") {
            first = trade
            break
        }
        #expect(first?.isBuy == true)
    }

    @Test("subscribeTrades fixture trade has correct price")
    func subscribeTradesFixturePrice() async throws {
        let sut = StubExchangeService()
        var first: AggTrade?
        for try await trade in sut.subscribeTrades(symbol: "BTCUSDT") {
            first = trade
            break
        }
        #expect(first?.price == 42200)
    }
}
