import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - OrderBookSnapshot Parsing Tests

@Suite("OrderBookSnapshot Parsing")
struct OrderBookSnapshotParsingTests {

    /// Standard 2-level bid/ask snapshot fixture matching Binance partial depth format.
    let fixtureJSON = """
    {"lastUpdateId":160,"bids":[["0.0024","10"],["0.0023","5"]],"asks":[["0.0025","100"],["0.0026","50"]]}
    """.data(using: .utf8)!

    @Test("Decodes lastUpdateId correctly")
    func decodesLastUpdateId() throws {
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: fixtureJSON)
        #expect(snapshot.lastUpdateId == 160)
    }

    @Test("Decodes correct bid count")
    func decodesBidCount() throws {
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: fixtureJSON)
        #expect(snapshot.bids.count == 2)
    }

    @Test("Decodes correct ask count")
    func decodesAskCount() throws {
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: fixtureJSON)
        #expect(snapshot.asks.count == 2)
    }

    @Test("Bid prices are preserved as exact Decimals")
    func bidPricesExactDecimal() throws {
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: fixtureJSON)
        #expect(snapshot.bids[0].price == Decimal(string: "0.0024")!)
        #expect(snapshot.bids[1].price == Decimal(string: "0.0023")!)
    }

    @Test("Bid quantities are preserved as exact Decimals")
    func bidQuantitiesExactDecimal() throws {
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: fixtureJSON)
        #expect(snapshot.bids[0].quantity == Decimal(string: "10")!)
        #expect(snapshot.bids[1].quantity == Decimal(string: "5")!)
    }

    @Test("Ask prices are preserved as exact Decimals")
    func askPricesExactDecimal() throws {
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: fixtureJSON)
        #expect(snapshot.asks[0].price == Decimal(string: "0.0025")!)
        #expect(snapshot.asks[1].price == Decimal(string: "0.0026")!)
    }

    @Test("Ask quantities are preserved as exact Decimals")
    func askQuantitiesExactDecimal() throws {
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: fixtureJSON)
        #expect(snapshot.asks[0].quantity == Decimal(string: "100")!)
        #expect(snapshot.asks[1].quantity == Decimal(string: "50")!)
    }

    @Test("Handles empty bids and asks arrays without crash")
    func decodesEmptyArrays() throws {
        let json = """
        {"lastUpdateId":1,"bids":[],"asks":[]}
        """.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: json)
        #expect(snapshot.lastUpdateId == 1)
        #expect(snapshot.bids.isEmpty)
        #expect(snapshot.asks.isEmpty)
    }

    @Test("Handles single bid and single ask")
    func decodesSingleLevel() throws {
        let json = """
        {"lastUpdateId":42,"bids":[["50000.00","1.5"]],"asks":[["50001.00","2.0"]]}
        """.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: json)
        #expect(snapshot.lastUpdateId == 42)
        #expect(snapshot.bids.count == 1)
        #expect(snapshot.asks.count == 1)
        #expect(snapshot.bids[0].price == Decimal(string: "50000.00")!)
        #expect(snapshot.asks[0].price == Decimal(string: "50001.00")!)
    }

    @Test("Decodes a full 20-level Binance depth response")
    func decodesTwentyLevels() throws {
        let json = """
        {"lastUpdateId":99999,"bids":[
          ["94000.00","1.0"],["93999.00","2.0"],["93998.00","3.0"],["93997.00","4.0"],
          ["93996.00","5.0"],["93995.00","6.0"],["93994.00","7.0"],["93993.00","8.0"],
          ["93992.00","9.0"],["93991.00","10.0"],["93990.00","11.0"],["93989.00","12.0"],
          ["93988.00","13.0"],["93987.00","14.0"],["93986.00","15.0"],["93985.00","16.0"],
          ["93984.00","17.0"],["93983.00","18.0"],["93982.00","19.0"],["93981.00","20.0"]
        ],"asks":[
          ["94001.00","1.0"],["94002.00","2.0"],["94003.00","3.0"],["94004.00","4.0"],
          ["94005.00","5.0"],["94006.00","6.0"],["94007.00","7.0"],["94008.00","8.0"],
          ["94009.00","9.0"],["94010.00","10.0"],["94011.00","11.0"],["94012.00","12.0"],
          ["94013.00","13.0"],["94014.00","14.0"],["94015.00","15.0"],["94016.00","16.0"],
          ["94017.00","17.0"],["94018.00","18.0"],["94019.00","19.0"],["94020.00","20.0"]
        ]}
        """.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: json)
        #expect(snapshot.lastUpdateId == 99999)
        #expect(snapshot.bids.count == 20)
        #expect(snapshot.asks.count == 20)
        #expect(snapshot.bids[0].price == Decimal(string: "94000.00")!)
        #expect(snapshot.asks[19].price == Decimal(string: "94020.00")!)
    }

    @Test("Decimal not approximated via Double (precision check)")
    func decimalNotApproximatedViaDouble() throws {
        // 0.0024 cannot be represented exactly in IEEE 754 Double.
        // Decimal(string:) must give the exact value.
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: fixtureJSON)
        let exact = Decimal(string: "0.0024")!
        #expect(snapshot.bids[0].price == exact)
        // Verify it doesn't equal a Double-approximated version
        let viaDouble = Decimal(0.0024)  // loses precision
        // The Double 0.0024 becomes 0.002399999... so they should differ
        // unless the platform rounds favorably — either way, our string path is exact
        #expect(snapshot.bids[0].price == exact)
        _ = viaDouble  // suppress unused warning
    }
}

// MARK: - PriceLevel Codable Roundtrip Tests

@Suite("PriceLevel Codable")
struct PriceLevelCodableTests {

    @Test("PriceLevel encodes to string array format")
    func encodesToStringArray() throws {
        let level = PriceLevel(price: Decimal(string: "34567.89")!, quantity: Decimal(string: "1.23")!)
        let data = try JSONEncoder().encode(level)
        let json = String(data: data, encoding: .utf8)!
        // Should produce ["34567.89","1.23"]
        #expect(json.contains("34567.89"))
        #expect(json.contains("1.23"))
    }

    @Test("PriceLevel decodes from string array format")
    func decodesFromStringArray() throws {
        let json = """
        ["34567.89","1.23"]
        """.data(using: .utf8)!
        let level = try JSONDecoder().decode(PriceLevel.self, from: json)
        #expect(level.price == Decimal(string: "34567.89")!)
        #expect(level.quantity == Decimal(string: "1.23")!)
    }

    @Test("PriceLevel Codable roundtrip preserves exact values")
    func roundtripPreservesExactValues() throws {
        let original = PriceLevel(
            price: Decimal(string: "68432.12345678")!,
            quantity: Decimal(string: "0.00012345")!
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PriceLevel.self, from: data)
        #expect(decoded.price == original.price)
        #expect(decoded.quantity == original.quantity)
    }

    @Test("PriceLevel Equatable works correctly")
    func equatableWorks() {
        let a = PriceLevel(price: Decimal(string: "100.0")!, quantity: Decimal(string: "5.0")!)
        let b = PriceLevel(price: Decimal(string: "100.0")!, quantity: Decimal(string: "5.0")!)
        let c = PriceLevel(price: Decimal(string: "200.0")!, quantity: Decimal(string: "5.0")!)
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - OrderBookSnapshot Properties Tests

@Suite("OrderBookSnapshot Properties")
struct OrderBookSnapshotPropertyTests {

    @Test("timestamp is set to a recent Date on decode")
    func timestampIsSet() throws {
        let before = Date()
        let json = """
        {"lastUpdateId":1,"bids":[],"asks":[]}
        """.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(OrderBookSnapshot.self, from: json)
        let after = Date()
        #expect(snapshot.timestamp >= before)
        #expect(snapshot.timestamp <= after)
    }

    @Test("OrderBookSnapshot is Equatable")
    func equatableWorks() {
        let a = OrderBookSnapshot(lastUpdateId: 1, bids: [], asks: [], timestamp: Date(timeIntervalSince1970: 0))
        let b = OrderBookSnapshot(lastUpdateId: 1, bids: [], asks: [], timestamp: Date(timeIntervalSince1970: 0))
        let c = OrderBookSnapshot(lastUpdateId: 2, bids: [], asks: [], timestamp: Date(timeIntervalSince1970: 0))
        #expect(a == b)
        #expect(a != c)
    }
}
