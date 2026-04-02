import Foundation

func rsi(klines: [Kline], period: Int) -> [IndicatorValue] {
    guard period > 0, klines.count > period else { return [] }

    let periodDecimal = Decimal(period)
    let smoothingWeight = Decimal(period - 1)

    var averageGain: Decimal = 0
    var averageLoss: Decimal = 0

    for index in 1...period {
        let change = klines[index].close - klines[index - 1].close
        if change > 0 {
            averageGain += change
        } else if change < 0 {
            averageLoss -= change
        }
    }

    averageGain /= periodDecimal
    averageLoss /= periodDecimal

    var series: [IndicatorValue] = [
        IndicatorValue(
            time: klines[period].openTime,
            value: rsiValue(averageGain: averageGain, averageLoss: averageLoss)
        )
    ]

    guard klines.count > period + 1 else { return series }

    for index in (period + 1)..<klines.count {
        let change = klines[index].close - klines[index - 1].close
        let gain = change > 0 ? change : Decimal.zero
        let loss = change < 0 ? -change : Decimal.zero

        averageGain = ((averageGain * smoothingWeight) + gain) / periodDecimal
        averageLoss = ((averageLoss * smoothingWeight) + loss) / periodDecimal

        series.append(
            IndicatorValue(
                time: klines[index].openTime,
                value: rsiValue(averageGain: averageGain, averageLoss: averageLoss)
            )
        )
    }

    return series
}

private func rsiValue(averageGain: Decimal, averageLoss: Decimal) -> Decimal {
    if averageLoss == 0 {
        return averageGain == 0 ? Decimal(50) : Decimal(100)
    }

    if averageGain == 0 {
        return .zero
    }

    let relativeStrength = averageGain / averageLoss
    return Decimal(100) - (Decimal(100) / (Decimal(1) + relativeStrength))
}
