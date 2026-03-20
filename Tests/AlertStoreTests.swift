import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Helpers

/// Returns a fresh `AlertStore` with cleared UserDefaults state so tests don't
/// touch real user data and don't interfere with each other.
@MainActor
private func makeStore() -> AlertStore {
    UserDefaults.standard.removeObject(forKey: "priceAlerts")
    return AlertStore()
}

// MARK: - CRUD

@Suite("AlertStore CRUD")
struct AlertStoreCRUDTests {

    @Test("Add alert increases count by one")
    @MainActor
    func addIncrementsCount() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        #expect(store.alerts.count == 1)
    }

    @Test("Added alert has correct price and direction")
    @MainActor
    func addStoresCorrectValues() {
        let store = makeStore()
        store.add(price: Decimal(string: "42000.50")!, direction: .below)
        let alert = store.alerts[0]
        #expect(alert.price == Decimal(string: "42000.50"))
        #expect(alert.direction == .below)
        #expect(alert.isEnabled == true)
        #expect(alert.hasTriggered == false)
    }

    @Test("Remove alert by id decreases count")
    @MainActor
    func removeDecreasesCount() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        store.add(price: 41000, direction: .below)
        let id = store.alerts[0].id
        store.remove(id: id)
        #expect(store.alerts.count == 1)
    }

    @Test("Remove non-existent id is a no-op")
    @MainActor
    func removeNonExistentIsNoOp() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        store.remove(id: UUID())   // random UUID — should not crash or remove anything
        #expect(store.alerts.count == 1)
    }
}

// MARK: - Crossing Detection

@Suite("AlertStore Crossing Detection")
struct AlertStoreCrossingTests {

    @Test("Above alert fires on upward crossing")
    @MainActor
    func aboveCrossingFires() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        let fired = store.check(currentPrice: 42000, previousPrice: 41999)
        #expect(fired.count == 1)
        #expect(fired[0].direction == .above)
    }

    @Test("Above alert fires when current equals threshold exactly")
    @MainActor
    func aboveFiresOnExactThreshold() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        // previousPrice < threshold, currentPrice == threshold → should fire
        let fired = store.check(currentPrice: 42000, previousPrice: 41900)
        #expect(fired.count == 1)
    }

    @Test("Above alert does not fire when price was already above threshold")
    @MainActor
    func aboveDoesNotFireWhenAlreadyAbove() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        // Both prices already above threshold — no crossing
        let fired = store.check(currentPrice: 42100, previousPrice: 42050)
        #expect(fired.isEmpty)
    }

    @Test("Below alert fires on downward crossing")
    @MainActor
    func belowCrossingFires() {
        let store = makeStore()
        store.add(price: 41000, direction: .below)
        let fired = store.check(currentPrice: 41000, previousPrice: 41001)
        #expect(fired.count == 1)
        #expect(fired[0].direction == .below)
    }

    @Test("Below alert fires when current equals threshold exactly")
    @MainActor
    func belowFiresOnExactThreshold() {
        let store = makeStore()
        store.add(price: 41000, direction: .below)
        let fired = store.check(currentPrice: 41000, previousPrice: 41100)
        #expect(fired.count == 1)
    }

    @Test("Below alert does not fire when price was already below threshold")
    @MainActor
    func belowDoesNotFireWhenAlreadyBelow() {
        let store = makeStore()
        store.add(price: 41000, direction: .below)
        let fired = store.check(currentPrice: 40900, previousPrice: 40800)
        #expect(fired.isEmpty)
    }

    @Test("Non-crossing check returns empty array")
    @MainActor
    func nonCrossingReturnsEmpty() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        // Price moved up but stayed below threshold
        let fired = store.check(currentPrice: 41999, previousPrice: 41500)
        #expect(fired.isEmpty)
    }

    @Test("hasTriggered prevents re-fire on subsequent ticks")
    @MainActor
    func hasTriggeredPreventsRefire() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)

        // First crossing — should fire
        let first = store.check(currentPrice: 42000, previousPrice: 41999)
        #expect(first.count == 1)

        // Same crossing again — should NOT fire because hasTriggered=true
        let second = store.check(currentPrice: 42001, previousPrice: 41999)
        #expect(second.isEmpty)
    }

    @Test("hasTriggered is set to true after alert fires")
    @MainActor
    func hasTriggeredSetAfterFiring() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        store.check(currentPrice: 42000, previousPrice: 41999)
        #expect(store.alerts[0].hasTriggered == true)
    }

    @Test("Disabled alert does not fire")
    @MainActor
    func disabledAlertDoesNotFire() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        // Manually disable via internal mutation — remove and re-add with isEnabled=false
        let id = store.alerts[0].id
        store.remove(id: id)
        // Add a pre-disabled alert by adding then checking at a non-crossing price,
        // then toggle isEnabled via direct struct mutation test:
        // Actually we test the AlertStore path: create a store with a pre-disabled alert.
        // Since we can't set isEnabled to false via `add()`, we test via persistence:
        let alert = PriceAlert(price: 42000, direction: .above, isEnabled: false)
        let encoder = JSONEncoder()
        if let data = try? encoder.encode([alert]) {
            UserDefaults.standard.set(data, forKey: "priceAlerts")
        }
        let storeWithDisabled = AlertStore()
        let fired = storeWithDisabled.check(currentPrice: 42000, previousPrice: 41999)
        #expect(fired.isEmpty)
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "priceAlerts")
    }
}

// MARK: - Re-arm

@Suite("AlertStore Re-arm")
struct AlertStoreRearmTests {

    @Test("resetAlert clears hasTriggered")
    @MainActor
    func resetAlertClearsHasTriggered() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        store.check(currentPrice: 42000, previousPrice: 41999)
        #expect(store.alerts[0].hasTriggered == true)

        store.resetAlert(id: store.alerts[0].id)
        #expect(store.alerts[0].hasTriggered == false)
    }

    @Test("Alert fires again after reset")
    @MainActor
    func alertFiresAgainAfterReset() {
        let store = makeStore()
        store.add(price: 42000, direction: .above)
        store.check(currentPrice: 42000, previousPrice: 41999)

        store.resetAlert(id: store.alerts[0].id)

        // Cross threshold again
        let second = store.check(currentPrice: 42000, previousPrice: 41999)
        #expect(second.count == 1)
    }
}

// MARK: - Persistence Round-trip

@Suite("AlertStore Persistence")
struct AlertStorePersistenceTests {

    @Test("Alerts survive encode-UserDefaults-decode round-trip")
    @MainActor
    func persistenceRoundTrip() {
        // Clean slate
        UserDefaults.standard.removeObject(forKey: "priceAlerts")

        let price = Decimal(string: "42000.12345678")!

        // Store 1: add an alert
        let store1 = AlertStore()
        store1.add(price: price, direction: .above)
        let originalId = store1.alerts[0].id

        // Store 2: load from UserDefaults
        let store2 = AlertStore()
        #expect(store2.alerts.count == 1)
        #expect(store2.alerts[0].id == originalId)
        #expect(store2.alerts[0].price == price, "Decimal precision must be preserved through String encoding")
        #expect(store2.alerts[0].direction == .above)
        #expect(store2.alerts[0].isEnabled == true)
        #expect(store2.alerts[0].hasTriggered == false)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "priceAlerts")
    }

    @Test("hasTriggered=true persists and reloads correctly")
    @MainActor
    func hasTriggeredPersists() {
        UserDefaults.standard.removeObject(forKey: "priceAlerts")

        let store1 = AlertStore()
        store1.add(price: 42000, direction: .above)
        store1.check(currentPrice: 42000, previousPrice: 41999)
        #expect(store1.alerts[0].hasTriggered == true)

        let store2 = AlertStore()
        #expect(store2.alerts[0].hasTriggered == true)

        UserDefaults.standard.removeObject(forKey: "priceAlerts")
    }

    @Test("PriceAlert Decimal Codable round-trip preserves high-precision values")
    func decimalPrecisionRoundTrip() throws {
        let price = Decimal(string: "12345678.87654321")!
        let alert = PriceAlert(price: price, direction: .above)
        let data = try JSONEncoder().encode(alert)
        let decoded = try JSONDecoder().decode(PriceAlert.self, from: data)
        #expect(decoded.price == price, "Decimal precision must survive encode/decode via String")
    }
}
