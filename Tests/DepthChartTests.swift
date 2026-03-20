import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Fixture helpers

private func makeLevel(price: Decimal, quantity: Decimal = 1) -> PriceLevel {
    PriceLevel(price: price, quantity: quantity)
}

// MARK: - Test Suite

@Suite("DepthChartView cumulative computation")
struct DepthChartTests {

    // MARK: Empty input

    @Test("emptyLevels_returnsEmpty — empty input produces empty output")
    func emptyLevels_returnsEmpty() {
        let result = depthCumulativeLevels(from: [], sortDescending: true)
        #expect(result.isEmpty)
    }

    // MARK: Single level

    @Test("singleLevel_returnsSameQuantity — single level cumulative equals its own quantity")
    func singleLevel_returnsSameQuantity() {
        let levels = [makeLevel(price: 100, quantity: 5)]
        let result = depthCumulativeLevels(from: levels, sortDescending: true)

        #expect(result.count == 1)
        #expect(result[0].cumulativeQty == 5)
        #expect(result[0].price == 100)
    }

    // MARK: Multi-level cumulative sums

    @Test("multipleLevels_correctCumulativeSums — quantities 1,2,3 yield cumulative 1,3,6")
    func multipleLevels_correctCumulativeSums() {
        // Ask side: ascending price order, quantities 1, 2, 3
        let levels = [
            makeLevel(price: 101, quantity: 1),
            makeLevel(price: 102, quantity: 2),
            makeLevel(price: 103, quantity: 3)
        ]
        let result = depthCumulativeLevels(from: levels, sortDescending: false)

        #expect(result.count == 3)
        #expect(result[0].cumulativeQty == 1)
        #expect(result[1].cumulativeQty == 3)
        #expect(result[2].cumulativeQty == 6)
    }

    // MARK: Monotonically non-decreasing

    @Test("cumulativeIsMonotonicallyNonDecreasing — each step is >= the previous")
    func cumulativeIsMonotonicallyNonDecreasing() {
        let levels = [
            makeLevel(price: 99,  quantity: 3),
            makeLevel(price: 98,  quantity: 0),   // zero qty edge case
            makeLevel(price: 97,  quantity: 7),
            makeLevel(price: 96,  quantity: 2),
            makeLevel(price: 95,  quantity: 5)
        ]
        let result = depthCumulativeLevels(from: levels, sortDescending: true)

        for i in 1..<result.count {
            #expect(result[i].cumulativeQty >= result[i - 1].cumulativeQty,
                    "Expected non-decreasing at index \(i): \(result[i].cumulativeQty) >= \(result[i - 1].cumulativeQty)")
        }
    }

    // MARK: Sort direction — bids descending, asks ascending

    @Test("bidsSortedDescending_asksSortedAscending — sort direction is correct for each side")
    func bidsSortedDescending_asksSortedAscending() {
        // Deliberately supply levels in shuffled order to prove sorting
        let bids = [
            makeLevel(price: 97, quantity: 1),
            makeLevel(price: 100, quantity: 1),
            makeLevel(price: 99, quantity: 1),
            makeLevel(price: 98, quantity: 1)
        ]
        let asks = [
            makeLevel(price: 103, quantity: 1),
            makeLevel(price: 101, quantity: 1),
            makeLevel(price: 104, quantity: 1),
            makeLevel(price: 102, quantity: 1)
        ]

        let bidResult = depthCumulativeLevels(from: bids, sortDescending: true)
        let askResult = depthCumulativeLevels(from: asks, sortDescending: false)

        // Bids: first price should be the highest (100)
        #expect(bidResult.first?.price == 100)
        // Bids: last price should be the lowest (97)
        #expect(bidResult.last?.price == 97)

        // Asks: first price should be the lowest (101)
        #expect(askResult.first?.price == 101)
        // Asks: last price should be the highest (104)
        #expect(askResult.last?.price == 104)
    }

    // MARK: Large dataset cumulative total

    @Test("largeDataset_totalEqualsSum — final cumulative equals sum of all quantities")
    func largeDataset_totalEqualsSum() {
        let quantities: [Decimal] = [10, 20, 5, 15, 8, 12, 3, 7]
        let expectedTotal = quantities.reduce(Decimal(0), +)

        let levels = quantities.enumerated().map { i, qty in
            makeLevel(price: Decimal(100 + i), quantity: qty)
        }

        let result = depthCumulativeLevels(from: levels, sortDescending: false)

        let actualTotal = CGFloat(NSDecimalNumber(decimal: expectedTotal).doubleValue)
        #expect(result.last?.cumulativeQty == actualTotal)
    }
}
