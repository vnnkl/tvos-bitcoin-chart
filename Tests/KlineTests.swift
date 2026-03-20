import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - REST Format Tests

@Suite("Kline REST Parsing")
struct KlineRESTTests {

    /// Standard 12-element REST kline array fixture.
    let restFixtureJSON = """
    [1625097600000,"34000.00","35000.00","33500.00","34800.00","125.5",
     1625097659999,"4366000.00",100,"62.5","2183000.00","0"]
    """.data(using: .utf8)!

    @Test("Decodes open price as Decimal")
    func decodesOpenPrice() throws {
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: restFixtureJSON)
        #expect(wrapper.kline.open == Decimal(string: "34000.00"))
    }

    @Test("Decodes high price as Decimal")
    func decodesHighPrice() throws {
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: restFixtureJSON)
        #expect(wrapper.kline.high == Decimal(string: "35000.00"))
    }

    @Test("Decodes low price as Decimal")
    func decodesLowPrice() throws {
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: restFixtureJSON)
        #expect(wrapper.kline.low == Decimal(string: "33500.00"))
    }

    @Test("Decodes close price as Decimal")
    func decodesClosePrice() throws {
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: restFixtureJSON)
        #expect(wrapper.kline.close == Decimal(string: "34800.00"))
    }

    @Test("Decodes volume as Decimal")
    func decodesVolume() throws {
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: restFixtureJSON)
        #expect(wrapper.kline.volume == Decimal(string: "125.5"))
    }

    @Test("Open time converts from ms to seconds")
    func decodesOpenTime() throws {
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: restFixtureJSON)
        let expected = Date(timeIntervalSince1970: 1_625_097_600.0)
        #expect(wrapper.kline.openTime == expected)
    }

    @Test("Close time converts from ms to seconds")
    func decodesCloseTime() throws {
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: restFixtureJSON)
        let expected = Date(timeIntervalSince1970: 1_625_097_659.999)
        // Allow sub-millisecond floating-point tolerance
        #expect(abs(wrapper.kline.closeTime.timeIntervalSince1970 - expected.timeIntervalSince1970) < 0.001)
    }

    @Test("isClosed defaults to true for REST klines")
    func isClosedTrue() throws {
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: restFixtureJSON)
        #expect(wrapper.kline.isClosed == true)
    }

    @Test("Decodes a REST response array of multiple klines")
    func decodesArray() throws {
        let json = """
        [[1625097600000,"34000.00","35000.00","33500.00","34800.00","125.5",
          1625097659999,"4366000.00",100,"62.5","2183000.00","0"],
         [1625097660000,"34800.00","35200.00","34700.00","35100.00","98.3",
          1625097719999,"3453000.00",80,"50.1","1760000.00","0"]]
        """.data(using: .utf8)!
        let wrappers = try JSONDecoder().decode([BinanceKlineREST].self, from: json)
        #expect(wrappers.count == 2)
        #expect(wrappers[1].kline.open == Decimal(string: "34800.00"))
    }
}

// MARK: - WebSocket Format Tests

@Suite("Kline WebSocket Parsing")
struct KlineWebSocketTests {

    let wsFixtureJSON = """
    {"e":"kline","E":123456,"s":"BTCUSDT","k":{"t":123456,"T":789012,
     "s":"BTCUSDT","i":"1m","o":"34000.00","c":"34800.00","h":"35000.00",
     "l":"33500.00","v":"125.5","x":false,"q":"0","V":"0","Q":"0","B":"0","n":0}}
    """.data(using: .utf8)!

    @Test("Decodes open price from WebSocket event")
    func decodesOpen() throws {
        let event = try JSONDecoder().decode(BinanceKlineEvent.self, from: wsFixtureJSON)
        #expect(event.kline.open == Decimal(string: "34000.00"))
    }

    @Test("Decodes close price from WebSocket event")
    func decodesClose() throws {
        let event = try JSONDecoder().decode(BinanceKlineEvent.self, from: wsFixtureJSON)
        #expect(event.kline.close == Decimal(string: "34800.00"))
    }

    @Test("Decodes high price from WebSocket event")
    func decodesHigh() throws {
        let event = try JSONDecoder().decode(BinanceKlineEvent.self, from: wsFixtureJSON)
        #expect(event.kline.high == Decimal(string: "35000.00"))
    }

    @Test("Decodes low price from WebSocket event")
    func decodesLow() throws {
        let event = try JSONDecoder().decode(BinanceKlineEvent.self, from: wsFixtureJSON)
        #expect(event.kline.low == Decimal(string: "33500.00"))
    }

    @Test("Decodes volume from WebSocket event")
    func decodesVolume() throws {
        let event = try JSONDecoder().decode(BinanceKlineEvent.self, from: wsFixtureJSON)
        #expect(event.kline.volume == Decimal(string: "125.5"))
    }

    @Test("isClosed is false when x=false in WebSocket event")
    func isClosedFalse() throws {
        let event = try JSONDecoder().decode(BinanceKlineEvent.self, from: wsFixtureJSON)
        #expect(event.kline.isClosed == false)
    }

    @Test("isClosed is true when x=true in WebSocket event")
    func isClosedTrue() throws {
        let json = """
        {"e":"kline","E":123456,"s":"BTCUSDT","k":{"t":123456,"T":789012,
         "s":"BTCUSDT","i":"1m","o":"34000.00","c":"34800.00","h":"35000.00",
         "l":"33500.00","v":"125.5","x":true,"q":"0","V":"0","Q":"0","B":"0","n":0}}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(BinanceKlineEvent.self, from: json)
        #expect(event.kline.isClosed == true)
    }

    @Test("Open time converts from ms in WebSocket event")
    func decodesOpenTime() throws {
        let event = try JSONDecoder().decode(BinanceKlineEvent.self, from: wsFixtureJSON)
        let expected = Date(timeIntervalSince1970: 123.456)
        #expect(abs(event.kline.openTime.timeIntervalSince1970 - expected.timeIntervalSince1970) < 0.001)
    }
}

// MARK: - Decimal Precision Tests

@Suite("Kline Decimal Precision")
struct KlineDecimalPrecisionTests {

    @Test("String price preserves exact Decimal value")
    func exactDecimalValue() throws {
        let json = """
        [1625097600000,"34567.89","35000.00","33500.00","34567.89","125.5",
         1625097659999,"4366000.00",100,"62.5","2183000.00","0"]
        """.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: json)
        let expected = Decimal(string: "34567.89")!
        #expect(wrapper.kline.open == expected)
    }

    @Test("Decimal is not approximated via Double")
    func notApproximatedViaDouble() throws {
        // 0.1 + 0.2 in Double = 0.30000000000000004 — Decimal must stay exact
        let json = """
        [1625097600000,"0.10","0.20","0.05","0.30","1.0",
         1625097659999,"0.0",0,"0.0","0.0","0"]
        """.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: json)
        #expect(wrapper.kline.open + wrapper.kline.high == Decimal(string: "0.30")!)
    }

    @Test("High-precision BTC price round-trips exactly")
    func highPrecisionRoundTrip() throws {
        let priceStr = "68432.12345678"
        let json = """
        [1625097600000,"\(priceStr)","68500.00","68000.00","\(priceStr)","50.0",
         1625097659999,"0.0",0,"0.0","0.0","0"]
        """.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(BinanceKlineREST.self, from: json)
        #expect(wrapper.kline.open == Decimal(string: priceStr)!)
    }
}

// MARK: - ConnectionState Tests

@Suite("ConnectionState")
struct ConnectionStateTests {

    @Test("All expected cases exist")
    func allCasesExist() {
        let all: [ConnectionState] = [.disconnected, .connecting, .connected, .reconnecting]
        #expect(all.count == 4)
    }

    @Test("Raw values match string names")
    func rawValues() {
        #expect(ConnectionState.disconnected.rawValue  == "disconnected")
        #expect(ConnectionState.connecting.rawValue    == "connecting")
        #expect(ConnectionState.connected.rawValue     == "connected")
        #expect(ConnectionState.reconnecting.rawValue  == "reconnecting")
    }
}
