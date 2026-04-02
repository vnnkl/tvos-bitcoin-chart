import Foundation

enum MarketRegimeKind: String, Sendable {
    case warmingUp
    case rangeCompression
    case balancedFlow
    case aggressiveBuyers
    case aggressiveSellers
    case trendUpBidsHolding
    case trendDownOffersHeavy
}

struct MarketRegimeState: Sendable, Equatable {
    let kind: MarketRegimeKind
    let title: String
    let summary: String

    static let warmingUp = MarketRegimeState(
        kind: .warmingUp,
        title: "Reading the Tape",
        summary: "Need a little more live history before classifying BTC."
    )
}

struct MarketRegimeTransition: Identifiable, Sendable, Equatable {
    let id = UUID()
    let regime: MarketRegimeState
}

func shouldAnnounceRegimeTransition(previous: MarketRegimeState, next: MarketRegimeState) -> Bool {
    previous.kind != .warmingUp && previous.kind != next.kind
}

func marketRegimeState(
    klines: [Kline],
    trades: [AggTrade],
    snapshot: OrderBookSnapshot?
) -> MarketRegimeState {
    let workingKlines = Array(klines.suffix(80))
    guard workingKlines.count >= 21 else { return .warmingUp }

    let metrics = MarketRegimeMetrics(klines: workingKlines, trades: trades, snapshot: snapshot)

    if metrics.isCompression {
        return MarketRegimeState(
            kind: .rangeCompression,
            title: "Range Compression",
            summary: "Range is tight, flow is muted, and BTC is coiling near the middle of the move."
        )
    }

    if metrics.bullishScore >= 4, metrics.depthImbalance >= -0.02 {
        return MarketRegimeState(
            kind: .trendUpBidsHolding,
            title: "Trend Up, Bids Holding",
            summary: "Price is leading above trend with \(metrics.tradeBiasText) and \(metrics.bookBiasText)."
        )
    }

    if metrics.bearishScore >= 4, metrics.depthImbalance <= 0.02 {
        return MarketRegimeState(
            kind: .trendDownOffersHeavy,
            title: "Trend Down, Offers Heavy",
            summary: "Price is slipping below trend while \(metrics.tradeBiasText) and \(metrics.bookBiasText)."
        )
    }

    if metrics.tradeImbalance >= 0.22, metrics.depthImbalance >= 0.04 {
        return MarketRegimeState(
            kind: .aggressiveBuyers,
            title: "Aggressive Buyers",
            summary: "Recent market buys dominate the tape and the near book is leaning bid-heavy."
        )
    }

    if metrics.tradeImbalance <= -0.22, metrics.depthImbalance <= -0.04 {
        return MarketRegimeState(
            kind: .aggressiveSellers,
            title: "Aggressive Sellers",
            summary: "Recent market sells dominate the tape and asks are stacking near the spread."
        )
    }

    return MarketRegimeState(
        kind: .balancedFlow,
        title: "Balanced Flow",
        summary: "Trend, tape, and liquidity are mixed right now; nothing dominant is taking over."
    )
}

private struct MarketRegimeMetrics {
    let bullishScore: Int
    let bearishScore: Int
    let tradeImbalance: Double
    let depthImbalance: Double
    let isCompression: Bool
    let tradeBiasText: String
    let bookBiasText: String

    init(klines: [Kline], trades: [AggTrade], snapshot: OrderBookSnapshot?) {
        let latestClose = decimalDouble(klines[klines.count - 1].close)
        let anchorIndex = max(0, klines.count - 8)
        let anchorClose = max(decimalDouble(klines[anchorIndex].close), 0.0001)
        let shortChange = (latestClose - anchorClose) / anchorClose

        let recentCandleSample = Array(klines.suffix(12))
        let averageRangeFraction = recentCandleSample.reduce(0.0) { partial, kline in
            let high = decimalDouble(kline.high)
            let low = decimalDouble(kline.low)
            let close = max(decimalDouble(kline.close), 0.0001)
            return partial + ((high - low) / close)
        } / Double(max(recentCandleSample.count, 1))

        let latestEMA = ema(klines: klines, period: 21).last.map { decimalDouble($0.value) }
        let latestSMA = sma(klines: klines, period: 50).last.map { decimalDouble($0.value) }
        let latestRSI = rsi(klines: klines, period: 14).last.map { decimalDouble($0.value) }

        let recentTrades = Array(trades.prefix(24))
        let buyVolume = recentTrades.filter(\.isBuy).reduce(0.0) { $0 + decimalDouble($1.quantity) }
        let sellVolume = recentTrades.filter { !$0.isBuy }.reduce(0.0) { $0 + decimalDouble($1.quantity) }
        let totalTradeVolume = buyVolume + sellVolume
        tradeImbalance = totalTradeVolume > 0 ? (buyVolume - sellVolume) / totalTradeVolume : 0

        if let snapshot {
            let bidDepth = snapshot.bids.prefix(5).reduce(0.0) { $0 + decimalDouble($1.quantity) }
            let askDepth = snapshot.asks.prefix(5).reduce(0.0) { $0 + decimalDouble($1.quantity) }
            let totalDepth = bidDepth + askDepth
            depthImbalance = totalDepth > 0 ? (bidDepth - askDepth) / totalDepth : 0
        } else {
            depthImbalance = 0
        }

        var bullish = 0
        var bearish = 0

        if let latestEMA {
            if latestClose > latestEMA {
                bullish += 1
            } else if latestClose < latestEMA {
                bearish += 1
            }
        }

        if let latestEMA, let latestSMA {
            if latestEMA > latestSMA {
                bullish += 1
            } else if latestEMA < latestSMA {
                bearish += 1
            }
        }

        if shortChange > 0.008 {
            bullish += 1
        } else if shortChange < -0.008 {
            bearish += 1
        }

        if let latestRSI {
            if latestRSI >= 58 {
                bullish += 1
            } else if latestRSI <= 42 {
                bearish += 1
            }
        }

        if tradeImbalance >= 0.12 {
            bullish += 1
        } else if tradeImbalance <= -0.12 {
            bearish += 1
        }

        if depthImbalance >= 0.08 {
            bullish += 1
        } else if depthImbalance <= -0.08 {
            bearish += 1
        }

        bullishScore = bullish
        bearishScore = bearish
        isCompression = abs(shortChange) <= 0.0035 && averageRangeFraction <= 0.0045 && abs(tradeImbalance) <= 0.12
        tradeBiasText = marketRegimeBiasText(
            for: tradeImbalance,
            positive: "buy flow still leads the tape",
            negative: "sell flow is still pressing"
        )
        bookBiasText = marketRegimeBiasText(
            for: depthImbalance,
            positive: "bids are leaning heavier near the spread",
            negative: "asks are leaning heavier near the spread"
        )
    }
}

private func decimalDouble(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
}

private func marketRegimeBiasText(for value: Double, positive: String, negative: String) -> String {
    if value >= 0.08 {
        return positive
    }
    if value <= -0.08 {
        return negative
    }
    return "liquidity is staying roughly balanced"
}
