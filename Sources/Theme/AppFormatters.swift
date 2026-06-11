import Foundation

/// Single home for every shared number and date formatter.
///
/// All number formatters are pinned to `Locale(identifier: "en_US")` so output
/// is period-decimal / comma-grouping regardless of device locale (R033).
/// Configurations are locked by `AppFormattersTests` — change them there first.
///
/// `@MainActor` because `NumberFormatter` / `DateFormatter` are not `Sendable`;
/// every consumer is a SwiftUI view, which is already main-actor isolated.
@MainActor
enum AppFormatters {

    // MARK: - Prices

    /// BTC price: 2 fraction digits, comma grouping (e.g. `70,358.64`).
    static let price: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    /// Axis tick price: whole numbers with grouping (e.g. `70,358`).
    static let axisPrice: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        return f
    }()

    /// 24 h change: 2 fraction digits (e.g. `-2.35`).
    static let change: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: - Volume / quantity

    /// Candle volume: 4 fraction digits with grouping (e.g. `12,345.6789`).
    static let volume: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 4
        f.maximumFractionDigits = 4
        f.usesGroupingSeparator = true
        return f
    }()

    /// Trade / order quantity: 4 fraction digits, no grouping (e.g. `0.0042`).
    static let quantity: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 4
        f.maximumFractionDigits = 4
        f.usesGroupingSeparator = false
        return f
    }()

    // MARK: - STRC dashboard

    /// BTC holdings totals: 2–4 fraction digits with grouping.
    static let btcHoldings: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 4
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    /// Per-filing BTC amounts: 2–3 fraction digits with grouping.
    static let btcFiling: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 3
        f.usesGroupingSeparator = true
        return f
    }()

    /// Share counts: whole numbers with grouping (e.g. `1,234,567`).
    static let shares: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    /// USD amounts: currency style, 2 fraction digits (e.g. `$70,358.64`).
    static let currencyUSD: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// Percentages already in percent form (11.5 → `11.5%`, not 0.115).
    static let percent: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .percent
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 2
        f.multiplier = 1
        return f
    }()

    // MARK: - Dates

    /// Trade feed timestamps (e.g. `14:32:05`).
    static let tradeTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Time-axis labels for intraday intervals (e.g. `14:30`).
    static let axisIntraday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// Time-axis labels for daily+ intervals (e.g. `Jun 11`).
    static let axisDaily: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd"
        return f
    }()

    /// Crosshair tooltip time (short style, no date).
    static let tooltipTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
