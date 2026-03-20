import Foundation

// MARK: - AlertDirection

/// Whether the alert triggers when price moves above or below the threshold.
enum AlertDirection: String, Codable, Sendable, CaseIterable {
    case above
    case below
}

// MARK: - PriceAlert

/// A single user-configured price alert.
///
/// **Precision contract:** `price` is stored as a `String` in JSON (not a bare `Decimal`)
/// to avoid the precision loss that occurs when Swift's default Decimal encode/decode
/// passes through a `Double` intermediary. The same pattern is used in `AggTrade` and `Kline`.
///
/// **Alert lifecycle:**
/// 1. Alert is created with `isEnabled = true`, `hasTriggered = false`.
/// 2. `AlertStore.check(currentPrice:previousPrice:)` fires the alert once and sets
///    `hasTriggered = true` to prevent repeated firing on subsequent ticks.
/// 3. Call `AlertStore.resetAlert(id:)` to re-arm the alert (`hasTriggered = false`).
struct PriceAlert: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    /// Price threshold for the alert. Stored as String in JSON for Decimal precision.
    let price: Decimal
    /// Whether this alert fires when price goes above or below the threshold.
    let direction: AlertDirection
    /// When `false` the alert is ignored during crossing checks.
    var isEnabled: Bool
    /// Set to `true` after the alert fires once. Prevents alert spam on subsequent ticks.
    /// Reset to `false` via `AlertStore.resetAlert(id:)`.
    var hasTriggered: Bool

    // MARK: - Init

    init(id: UUID = UUID(), price: Decimal, direction: AlertDirection, isEnabled: Bool = true, hasTriggered: Bool = false) {
        self.id = id
        self.price = price
        self.direction = direction
        self.isEnabled = isEnabled
        self.hasTriggered = hasTriggered
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, price, direction, isEnabled, hasTriggered
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)

        // Decode price from its String representation to preserve Decimal precision.
        let priceString = try c.decode(String.self, forKey: .price)
        guard let parsedPrice = Decimal(string: priceString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .price,
                in: c,
                debugDescription: "Cannot parse price as Decimal: \(priceString)"
            )
        }
        price = parsedPrice

        direction    = try c.decode(AlertDirection.self, forKey: .direction)
        isEnabled    = try c.decode(Bool.self, forKey: .isEnabled)
        hasTriggered = try c.decode(Bool.self, forKey: .hasTriggered)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        // Encode price as String to avoid Decimal → Double precision loss.
        try c.encode("\(price)", forKey: .price)
        try c.encode(direction, forKey: .direction)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encode(hasTriggered, forKey: .hasTriggered)
    }
}
