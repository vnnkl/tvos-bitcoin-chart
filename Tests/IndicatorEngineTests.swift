import Testing
import Foundation
@testable import BitcoinTerminal

@MainActor
private func makeIndicatorKline(index: Int, close: Decimal) -> Kline {
    Kline(
        openTime: Date(timeIntervalSince1970: Double(index) * 60),
        open: close,
        high: close + Decimal(1),
        low: close - Decimal(1),
        close: close,
        volume: Decimal(10),
        closeTime: Date(timeIntervalSince1970: Double(index) * 60 + 59),
        isClosed: true
    )
}

@Suite("Indicator Engines")
@MainActor
struct IndicatorEngineTests {

    @Test("SMA returns rolling average")
    func smaRollingAverage() {
        let klines = [1, 2, 3, 4, 5].enumerated().map {
            makeIndicatorKline(index: $0.offset, close: Decimal($0.element))
        }

        let values = sma(klines: klines, period: 3)

        #expect(values.map(\.value) == [Decimal(2), Decimal(3), Decimal(4)])
    }

    @Test("EMA uses SMA seed and smooths forward")
    func emaUsesStandardSeed() {
        let klines = [1, 2, 3, 4, 5].enumerated().map {
            makeIndicatorKline(index: $0.offset, close: Decimal($0.element))
        }

        let values = ema(klines: klines, period: 3)

        #expect(values.map(\.value) == [Decimal(2), Decimal(3), Decimal(4)])
    }

    @Test("RSI reaches 100 on uninterrupted gains")
    func rsiOnOnlyGains() {
        let klines = Array(1...16).enumerated().map {
            makeIndicatorKline(index: $0.offset, close: Decimal($0.element))
        }

        let values = rsi(klines: klines, period: 14)

        #expect(values.count == 2)
        #expect(values.allSatisfy { $0.value == Decimal(100) })
    }

    @Test("MACD stays flat on constant closes")
    func macdFlatSeries() {
        let klines = Array(repeating: Decimal(10), count: 40).enumerated().map {
            makeIndicatorKline(index: $0.offset, close: $0.element)
        }

        let values = macd(klines: klines, fast: 12, slow: 26, signal: 9)

        #expect(values.line.count == 15)
        #expect(values.signal.count == 7)
        #expect(values.histogram.count == 7)
        #expect(values.line.allSatisfy { $0.value == .zero })
        #expect(values.signal.allSatisfy { $0.value == .zero })
        #expect(values.histogram.allSatisfy { $0.value == .zero })
    }
}
