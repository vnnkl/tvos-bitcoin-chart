import Foundation

struct MACDSeries: Sendable, Equatable {
    let line: [IndicatorValue]
    let signal: [IndicatorValue]
    let histogram: [IndicatorValue]

    static let empty = MACDSeries(line: [], signal: [], histogram: [])
}

func macd(klines: [Kline], fast: Int, slow: Int, signal: Int) -> MACDSeries {
    guard fast > 0, slow > fast, signal > 0, klines.count >= slow else {
        return .empty
    }

    let fastEMA = emaValues(for: klines.map(\.close), period: fast)
    let slowEMA = emaValues(for: klines.map(\.close), period: slow)

    var line: [IndicatorValue] = []
    for index in klines.indices {
        guard let fastValue = fastEMA[index], let slowValue = slowEMA[index] else { continue }
        line.append(IndicatorValue(time: klines[index].openTime, value: fastValue - slowValue))
    }

    let signalValues = emaValues(for: line.map(\.value), period: signal).compactMap { $0 }
    let signalOffset = signal - 1

    let signalLine: [IndicatorValue] = signalValues.enumerated().map { index, value in
        IndicatorValue(time: line[index + signalOffset].time, value: value)
    }

    let histogram: [IndicatorValue] = signalLine.enumerated().map { index, signalPoint in
        let macdPoint = line[index + signalOffset]
        return IndicatorValue(time: signalPoint.time, value: macdPoint.value - signalPoint.value)
    }

    return MACDSeries(line: line, signal: signalLine, histogram: histogram)
}

private func emaValues(for values: [Decimal], period: Int) -> [Decimal?] {
    guard period > 0, values.count >= period else {
        return Array(repeating: nil, count: values.count)
    }

    let smoothing = Decimal(2) / Decimal(period + 1)
    let trailingWeight = Decimal(1) - smoothing
    let periodDecimal = Decimal(period)

    var results = Array<Decimal?>(repeating: nil, count: values.count)
    var seedSum: Decimal = 0

    for index in 0..<period {
        seedSum += values[index]
    }

    var currentEMA = seedSum / periodDecimal
    results[period - 1] = currentEMA

    guard values.count > period else { return results }

    for index in period..<values.count {
        currentEMA = (values[index] * smoothing) + (currentEMA * trailingWeight)
        results[index] = currentEMA
    }

    return results
}
