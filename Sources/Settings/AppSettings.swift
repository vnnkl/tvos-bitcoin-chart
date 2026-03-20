import Foundation
import Observation

/// Persists user preferences across app launches using `UserDefaults.standard`.
///
/// Uses computed properties with explicit get/set (not `@AppStorage`) because
/// `@AppStorage` requires a SwiftUI view context and cannot be used inside
/// `@Observable` classes. Each property reads and writes synchronously on access.
///
/// **Defaults:**
/// - `defaultInterval` → `"1m"`
/// - `defaultSymbol` → `"BTCUSDT"`
/// - `selectedExchange` → `"binance"`
@Observable
@MainActor
final class AppSettings {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let defaultInterval    = "appSettings.defaultInterval"
        static let defaultSymbol      = "appSettings.defaultSymbol"
        static let selectedExchange   = "appSettings.selectedExchange"
        static let hasSeenDisclaimer  = "appSettings.hasSeenDisclaimer"
    }

    // MARK: - Persisted Properties

    /// Kline interval string, e.g. `"1m"`, `"1h"`, `"1d"`. Default: `"1m"`.
    var defaultInterval: String {
        get { UserDefaults.standard.string(forKey: Keys.defaultInterval) ?? "1m" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultInterval) }
    }

    /// Trading pair symbol, e.g. `"BTCUSDT"`. Default: `"BTCUSDT"`.
    var defaultSymbol: String {
        get { UserDefaults.standard.string(forKey: Keys.defaultSymbol) ?? "BTCUSDT" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultSymbol) }
    }

    /// Exchange identifier: `"binance"` or `"stub"`. Default: `"binance"`.
    var selectedExchange: String {
        get { UserDefaults.standard.string(forKey: Keys.selectedExchange) ?? "binance" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.selectedExchange) }
    }

    /// Whether the user has acknowledged the financial disclaimer on first launch.
    /// Persisted via `UserDefaults`. Default: `false` (overlay shown until dismissed).
    var hasSeenDisclaimer: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasSeenDisclaimer) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasSeenDisclaimer) }
    }

    // MARK: - Init

    init() {}
}
