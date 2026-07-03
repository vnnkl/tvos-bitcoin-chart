import Testing
import Foundation
import CoreGraphics
@testable import BitcoinTerminal

@Suite("PriceScale")
struct PriceScaleTests {

    // MARK: - Price → Y mapping

    @Test func minPriceMapsToBottom() {
        let scale = PriceScale(priceMin: 100, priceRange: 100)
        #expect(scale.y(Decimal(100), in: 200) == 200)
    }

    @Test func maxPriceMapsToTop() {
        let scale = PriceScale(priceMin: 100, priceRange: 100)
        #expect(scale.y(Decimal(200), in: 200) == 0)
    }

    @Test func midPriceMapsToCenter() {
        let scale = PriceScale(priceMin: 100, priceRange: 100)
        #expect(scale.y(Decimal(150), in: 200) == 100)
    }

    /// Y axis is inverted: a higher price must produce a smaller Y.
    @Test func higherPriceYieldsLowerY() {
        let scale = PriceScale(priceMin: 30_000, priceRange: 5_000)
        let lowY  = scale.y(Decimal(31_000), in: 800)
        let highY = scale.y(Decimal(34_000), in: 800)
        #expect(highY < lowY)
    }

    /// CGFloat overload must agree with the Decimal overload.
    @Test func cgFloatOverloadMatchesDecimal() {
        let scale = PriceScale(priceMin: 100, priceRange: 50)
        #expect(scale.y(CGFloat(125), in: 300) == scale.y(Decimal(125), in: 300))
    }

    /// Decimal conversion must go through NSDecimalNumber, matching the
    /// rendering behavior of the original view-local helpers.
    @Test func decimalConversionMatchesNSDecimalNumber() {
        let price = Decimal(string: "34123.45")!
        let scale = PriceScale(priceMin: 30_000, priceRange: 10_000)
        let expected: CGFloat = {
            let p = CGFloat(NSDecimalNumber(decimal: price).doubleValue)
            return 600 - ((p - 30_000) / 10_000) * 600
        }()
        #expect(scale.y(price, in: 600) == expected)
    }

    // MARK: - Degenerate range guard

    @Test func zeroRangeMapsToVerticalCenter() {
        let scale = PriceScale(priceMin: 100, priceRange: 0)
        #expect(scale.y(Decimal(100), in: 400) == 200)
        #expect(scale.y(CGFloat(999), in: 400) == 200)
    }

    @Test func negativeRangeMapsToVerticalCenter() {
        let scale = PriceScale(priceMin: 100, priceRange: -5)
        #expect(scale.y(Decimal(100), in: 400) == 200)
    }

    // MARK: - Y → price (inverse, used by crosshair-style lookups)

    @Test func priceAtYInvertsYMapping() {
        let scale = PriceScale(priceMin: 100, priceRange: 100)
        let y = scale.y(Decimal(175), in: 400)
        #expect(abs(scale.price(atY: y, in: 400) - 175) < 0.0001)
    }

    @Test func priceAtZeroHeightReturnsPriceMin() {
        let scale = PriceScale(priceMin: 100, priceRange: 100)
        #expect(scale.price(atY: 0, in: 0) == 100)
    }

    // MARK: - Construction from klines (padded extents)

    @Test func klineInitMatchesPriceExtents() {
        let klines = [
            makeKline(low: 95, high: 105),
            makeKline(low: 90, high: 110),
        ]
        let scale = PriceScale(klines: klines)
        let (expectedMin, expectedRange) = priceExtents(klines)
        #expect(scale.priceMin == expectedMin)
        #expect(scale.priceRange == expectedRange)
    }

    // MARK: - Helpers

    private func makeKline(low: Decimal, high: Decimal) -> Kline {
        Kline(
            openTime: Date(timeIntervalSince1970: 0),
            open: low,
            high: high,
            low: low,
            close: high,
            volume: 1,
            closeTime: Date(timeIntervalSince1970: 59),
            isClosed: true
        )
    }
}
