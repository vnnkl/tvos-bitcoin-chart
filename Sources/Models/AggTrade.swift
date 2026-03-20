import Foundation

/// A single Binance aggregate trade from the `@aggTrade` WebSocket stream.
///
/// **Critical convention:** `isBuyerMaker: true` means the buyer was resting on the
/// order book — the **seller** was the aggressive taker, so the trade direction is SELL.
/// `isBuyerMaker: false` means the **buyer** was the taker → trade is a BUY.
/// Use the derived `isBuy` property for display logic to avoid this confusion.
///
/// Binance JSON format:
/// ```json
/// {"e":"aggTrade","E":1672531200000,"s":"BTCUSDT","a":123456789,
///  "p":"42000.50","q":"0.015","f":100,"l":105,"T":1672531200000,"m":true}
/// ```
struct AggTrade: Sendable, Equatable {
    /// Aggregate trade ID.
    let aggregateTradeId: Int
    /// Trade price — stored as `Decimal` for full precision (no floating-point drift).
    let price: Decimal
    /// Trade quantity — stored as `Decimal` for full precision.
    let quantity: Decimal
    /// Trade execution time.
    let time: Date
    /// Whether the buyer was the market maker (i.e. the seller was the aggressor).
    /// `true` → SELL; `false` → BUY. Prefer `isBuy` for display logic.
    let isBuyerMaker: Bool

    /// Convenience inverse of `isBuyerMaker` — `true` when a buyer was the taker (green trade).
    var isBuy: Bool { !isBuyerMaker }
}

// MARK: - Codable

extension AggTrade: Codable {
    enum CodingKeys: String, CodingKey {
        case aggregateTradeId = "a"
        case price            = "p"
        case quantity         = "q"
        case tradeTimeMs      = "T"
        case isBuyerMaker     = "m"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        aggregateTradeId = try c.decode(Int.self, forKey: .aggregateTradeId)

        // Price and quantity arrive as numeric strings — parse via Decimal(string:) to
        // preserve full precision (matches the pattern established in Kline / OrderBookLevel).
        let priceStr = try c.decode(String.self, forKey: .price)
        guard let parsedPrice = Decimal(string: priceStr) else {
            throw DecodingError.dataCorruptedError(
                forKey: .price,
                in: c,
                debugDescription: "Cannot parse price as Decimal: \(priceStr)"
            )
        }
        price = parsedPrice

        let qtyStr = try c.decode(String.self, forKey: .quantity)
        guard let parsedQty = Decimal(string: qtyStr) else {
            throw DecodingError.dataCorruptedError(
                forKey: .quantity,
                in: c,
                debugDescription: "Cannot parse quantity as Decimal: \(qtyStr)"
            )
        }
        quantity = parsedQty

        // Trade time arrives as milliseconds since epoch (Int64).
        let ms = try c.decode(Int64.self, forKey: .tradeTimeMs)
        time = Date(timeIntervalSince1970: Double(ms) / 1000.0)

        isBuyerMaker = try c.decode(Bool.self, forKey: .isBuyerMaker)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(aggregateTradeId, forKey: .aggregateTradeId)
        try c.encode("\(price)", forKey: .price)
        try c.encode("\(quantity)", forKey: .quantity)
        try c.encode(Int64(time.timeIntervalSince1970 * 1000), forKey: .tradeTimeMs)
        try c.encode(isBuyerMaker, forKey: .isBuyerMaker)
    }
}
