import Foundation

struct IndicatorValue: Sendable, Equatable {
    let time: Date
    let value: Decimal
}

func sma(klines: [Kline], period: Int) -> [IndicatorValue] {
    guard period > 0, klines.count >= period else { return [] }

    let periodDecimal = Decimal(period)
    var runningSum: Decimal = 0
    var series: [IndicatorValue] = []

    for index in klines.indices {
        runningSum += klines[index].close

        if index >= period {
            runningSum -= klines[index - period].close
        }

        guard index >= period - 1 else { continue }

        series.append(
            IndicatorValue(
                time: klines[index].openTime,
                value: runningSum / periodDecimal
            )
        )
    }

    return series
}

func ema(klines: [Kline], period: Int) -> [IndicatorValue] {
    guard period > 0, klines.count >= period else { return [] }

    let periodDecimal = Decimal(period)
    let smoothing = Decimal(2) / Decimal(period + 1)
    let trailingWeight = Decimal(1) - smoothing

    var seedSum: Decimal = 0
    for index in 0..<period {
        seedSum += klines[index].close
    }

    var currentEMA = seedSum / periodDecimal
    var series: [IndicatorValue] = [
        IndicatorValue(time: klines[period - 1].openTime, value: currentEMA)
    ]

    guard klines.count > period else { return series }

    for index in period..<klines.count {
        currentEMA = (klines[index].close * smoothing) + (currentEMA * trailingWeight)
        series.append(IndicatorValue(time: klines[index].openTime, value: currentEMA))
    }

    return series
}
