import Foundation
import Observation

@Observable
@MainActor
final class IndicatorSettings {

    private enum Keys {
        static let showEMA21 = "indicatorSettings.showEMA21"
        static let showSMA50 = "indicatorSettings.showSMA50"
        static let showRSI14 = "indicatorSettings.showRSI14"
        static let showMACD = "indicatorSettings.showMACD"
    }

    var showEMA21: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.showEMA21) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showEMA21)
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showEMA21) }
    }

    var showSMA50: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.showSMA50) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showSMA50) }
    }

    var showRSI14: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.showRSI14) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showRSI14) }
    }

    var showMACD: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.showMACD) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showMACD) }
    }

    init() {}
}
