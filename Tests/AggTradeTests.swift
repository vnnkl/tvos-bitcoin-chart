import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Helpers

private func decodeAggTrade(_ json: String) throws -> AggTrade {
    let data = json.data(using: .utf8)!
    return try JSONDecoder().decode(AggTrade.self, from: data)
}

// MARK: - Codable parsing

@Suite("AggTrade Codable Parsing")
struct AggTradeCodableTests {

    let validJSON = """
    {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":123456789,\
    "p":"42000.50","q":"0.01500000","f":100,"l":105,"T":1672531200000,"m":true}
    """

    @Test("Decodes aggregateTradeId from Binance JSON")
    func decodesFromBinanceJSON() throws {
        let trade = try decodeAggTrade(validJSON)
        #expect(trade.aggregateTradeId == 123456789)
    }

    @Test("Price decoded with exact Decimal precision")
    func decimalPrecisionPrice() throws {
        let trade = try decodeAggTrade(validJSON)
        // "42000.50" must decode without floating-point drift.
        #expect(trade.price == Decimal(string: "42000.50"))
    }

    @Test("Quantity decoded with exact Decimal precision")
    func decimalPrecisionQuantity() throws {
        let trade = try decodeAggTrade(validJSON)
        // "0.01500000" — trailing zeroes preserved as Decimal value.
        #expect(trade.quantity == Decimal(string: "0.01500000"))
    }

    @Test("Decimal does not use floating-point for high-precision values")
    func decimalDoesNotUseFloatingPoint() throws {
        // A value that loses precision as Double but is exact as Decimal.
        let json = """
        {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":1,\
        "p":"12345678.87654321","q":"0.00000001","f":1,"l":1,"T":1672531200000,"m":false}
        """
        let trade = try decodeAggTrade(json)
        #expect(trade.price == Decimal(string: "12345678.87654321"))
        #expect(trade.quantity == Decimal(string: "0.00000001"))
    }
}

// MARK: - isBuyerMaker semantics (critical Binance convention)

@Suite("AggTrade isBuyerMaker Semantics")
struct AggTradeDirectionTests {

    @Test("isBuyerMaker true means SELL (seller was aggressor)")
    func isBuyerMakerTrueMeansSell() throws {
        // m:true → buyer was resting (maker) → SELLER was aggressor → SELL trade
        let json = """
        {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":1,\
        "p":"42000.00","q":"0.1","f":1,"l":1,"T":1672531200000,"m":true}
        """
        let trade = try decodeAggTrade(json)
        #expect(trade.isBuyerMaker == true)
        #expect(trade.isBuy == false, "isBuyerMaker=true → seller was aggressor → isBuy must be false")
    }

    @Test("isBuyerMaker false means BUY (buyer was aggressor)")
    func isBuyerMakerFalseMeansBuy() throws {
        // m:false → buyer was aggressor (taker) → BUY trade
        let json = """
        {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":2,\
        "p":"42000.00","q":"0.1","f":2,"l":2,"T":1672531200000,"m":false}
        """
        let trade = try decodeAggTrade(json)
        #expect(trade.isBuyerMaker == false)
        #expect(trade.isBuy == true, "isBuyerMaker=false → buyer was aggressor → isBuy must be true")
    }

    @Test("isBuy is exact inverse of isBuyerMaker")
    func isBuyIsInverseOfIsBuyerMaker() throws {
        let json = """
        {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":3,\
        "p":"42000.00","q":"0.1","f":3,"l":3,"T":1672531200000,"m":true}
        """
        let trade = try decodeAggTrade(json)
        #expect(trade.isBuy == !trade.isBuyerMaker)
    }
}

// MARK: - Timestamp conversion

@Suite("AggTrade Timestamp Conversion")
struct AggTradeTimestampTests {

    @Test("Millisecond timestamp converts to correct Date")
    func timeConversionFromMilliseconds() throws {
        let json = """
        {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":1,\
        "p":"42000.50","q":"0.1","f":1,"l":1,"T":1672531200000,"m":true}
        """
        let trade = try decodeAggTrade(json)
        // T:1672531200000 ms = 1672531200 seconds (2023-01-01 00:00:00 UTC)
        let expectedTimestamp: TimeInterval = 1_672_531_200.0
        #expect(abs(trade.time.timeIntervalSince1970 - expectedTimestamp) < 0.001)
    }

    @Test("Subsecond precision preserved from millisecond timestamp")
    func timeSubsecondPrecision() throws {
        // Timestamp with fractional seconds: 1672531200500 ms = .500 seconds
        let json = """
        {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":99,\
        "p":"42000.00","q":"0.1","f":1,"l":1,"T":1672531200500,"m":false}
        """
        let trade = try decodeAggTrade(json)
        #expect(abs(trade.time.timeIntervalSince1970 - 1_672_531_200.5) < 0.001)
    }
}

// MARK: - Equatable

@Suite("AggTrade Equatable")
struct AggTradeEquatableTests {

    @Test("Two trades from same JSON are equal")
    func equatableSameValues() throws {
        let json = """
        {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":123456789,\
        "p":"42000.50","q":"0.01500000","f":100,"l":105,"T":1672531200000,"m":true}
        """
        let a = try decodeAggTrade(json)
        let b = try decodeAggTrade(json)
        #expect(a == b)
    }

    @Test("Trades with different aggregateTradeId are not equal")
    func equatableDifferentAggregateId() throws {
        let json1 = """
        {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":123456789,\
        "p":"42000.50","q":"0.01500000","f":100,"l":105,"T":1672531200000,"m":true}
        """
        let json2 = """
        {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":999999999,\
        "p":"42000.50","q":"0.01500000","f":100,"l":105,"T":1672531200000,"m":true}
        """
        let a = try decodeAggTrade(json1)
        let b = try decodeAggTrade(json2)
        #expect(a != b)
    }
}
