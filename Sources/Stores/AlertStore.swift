import Foundation
import Observation

/// CRUD store for user price alerts with threshold-crossing detection.
///
/// **Crossing detection rules:**
/// - `.above`: fires when `previousPrice < alert.price && currentPrice >= alert.price`
/// - `.below`: fires when `previousPrice > alert.price && currentPrice <= alert.price`
/// Exact equality (`currentPrice == threshold`) is intentionally avoided — price ticks
/// rarely land exactly on a threshold, so the range check is required.
///
/// **Spam prevention:** `hasTriggered` is set to `true` on first fire. The alert will
/// not fire again until `resetAlert(id:)` is called (re-arms it).
///
/// **Persistence:** alerts are stored as JSON in `UserDefaults.standard` under the key
/// `"priceAlerts"`. Every mutation (`add`, `remove`, `check`, `resetAlert`) saves automatically.
///
/// **Inspectable state:**
/// - `alertStore.alerts.count` — total alerts configured
/// - `alertStore.alerts.filter { $0.hasTriggered }.count` — how many have fired
/// - `alertStore.alerts.filter { $0.isEnabled && !$0.hasTriggered }.count` — active, armed alerts
@Observable
@MainActor
final class AlertStore {

    // MARK: - UserDefaults Key

    private static let defaultsKey = "priceAlerts"

    // MARK: - State

    /// All configured alerts. Read-only externally; mutated via `add`, `remove`, `check`, `reset`.
    private(set) var alerts: [PriceAlert]

    // MARK: - Init

    init() {
        alerts = AlertStore.load()
    }

    // MARK: - CRUD

    /// Adds a new enabled, un-triggered alert and persists immediately.
    func add(price: Decimal, direction: AlertDirection) {
        let alert = PriceAlert(price: price, direction: direction)
        alerts.append(alert)
        save()
    }

    /// Removes the alert with the given `id` and persists immediately.
    func remove(id: UUID) {
        alerts.removeAll { $0.id == id }
        save()
    }

    // MARK: - Crossing Detection

    /// Checks all enabled, un-triggered alerts against a price tick.
    ///
    /// Returns alerts whose threshold was crossed between `previousPrice` and `currentPrice`.
    /// Sets `hasTriggered = true` on every returned alert to prevent re-firing.
    ///
    /// Returns an empty array when no crossings occur — this is the normal case for most ticks.
    ///
    /// - Parameters:
    ///   - currentPrice:  The latest price (the new tick value).
    ///   - previousPrice: The price from the immediately preceding tick.
    @discardableResult
    func check(currentPrice: Decimal, previousPrice: Decimal) -> [PriceAlert] {
        var fired: [PriceAlert] = []

        for i in alerts.indices {
            let alert = alerts[i]
            guard alert.isEnabled && !alert.hasTriggered else { continue }

            let crosses: Bool
            switch alert.direction {
            case .above:
                // Fires on upward crossing: was below threshold, now at or above.
                crosses = previousPrice < alert.price && currentPrice >= alert.price
            case .below:
                // Fires on downward crossing: was above threshold, now at or below.
                crosses = previousPrice > alert.price && currentPrice <= alert.price
            }

            if crosses {
                alerts[i].hasTriggered = true
                fired.append(alerts[i])
            }
        }

        if !fired.isEmpty { save() }
        return fired
    }

    // MARK: - Re-arm

    /// Resets `hasTriggered` to `false` so the alert can fire again.
    func resetAlert(id: UUID) {
        guard let i = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[i].hasTriggered = false
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(alerts) else { return }
        UserDefaults.standard.set(data, forKey: AlertStore.defaultsKey)
    }

    private static func load() -> [PriceAlert] {
        guard
            let data = UserDefaults.standard.data(forKey: AlertStore.defaultsKey),
            let decoded = try? JSONDecoder().decode([PriceAlert].self, from: data)
        else { return [] }
        return decoded
    }
}
