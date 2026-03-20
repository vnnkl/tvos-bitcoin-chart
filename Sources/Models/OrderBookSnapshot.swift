import Foundation

// MARK: - PriceLevel

/// A single price level in the order book, representing one row in the bid or ask ladder.
///
/// Binance sends each level as a two-element JSON string array: `["price", "quantity"]`.
/// Custom Codable decodes from that array format while keeping Decimal exact — no Double.
struct PriceLevel: Sendable, Equatable, Codable {
    let price: Decimal
    let quantity: Decimal

    // MARK: Codable

    init(price: Decimal, quantity: Decimal) {
        self.price = price
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let priceString = try container.decode(String.self)
        let quantityString = try container.decode(String.self)

        guard let p = Decimal(string: priceString) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot convert price string '\(priceString)' to Decimal"
            )
        }
        guard let q = Decimal(string: quantityString) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot convert quantity string '\(quantityString)' to Decimal"
            )
        }
        self.price = p
        self.quantity = q
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(price.description)
        try container.encode(quantity.description)
    }
}

// MARK: - OrderBookSnapshot

/// A complete snapshot of the top-20 bid and ask levels from Binance's partial depth stream.
///
/// Binance partial book depth stream (`btcusdt@depth20@100ms`) format:
/// ```json
/// {"lastUpdateId": 160, "bids": [["0.0024","10"],...], "asks": [["0.0025","100"],...]}
/// ```
///
/// Each 100ms message is a self-contained snapshot (no reconciliation needed).
struct OrderBookSnapshot: Sendable, Equatable, Codable {
    let lastUpdateId: Int
    let bids: [PriceLevel]
    let asks: [PriceLevel]
    let timestamp: Date

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case lastUpdateId
        case bids
        case asks
    }

    init(lastUpdateId: Int, bids: [PriceLevel], asks: [PriceLevel], timestamp: Date = Date()) {
        self.lastUpdateId = lastUpdateId
        self.bids = bids
        self.asks = asks
        self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastUpdateId = try container.decode(Int.self, forKey: .lastUpdateId)
        bids = try container.decode([PriceLevel].self, forKey: .bids)
        asks = try container.decode([PriceLevel].self, forKey: .asks)
        timestamp = Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lastUpdateId, forKey: .lastUpdateId)
        try container.encode(bids, forKey: .bids)
        try container.encode(asks, forKey: .asks)
        // timestamp is synthetic — not round-tripped to/from JSON
    }
}
