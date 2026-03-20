import Testing
import Foundation

/// Verifies that `NumberFormatter` instances pinned to `Locale(identifier: "en_US")`
/// always produce period-decimal, comma-grouping output regardless of device locale.
///
/// This test proves R033: any device locale (e.g. de_DE which uses `.` as thousands
/// separator and `,` as decimal) will still produce `70,358.64` when the formatter
/// locale is explicitly set to `en_US`.
@Suite("Locale-pinned NumberFormatter")
struct FormatterTests {

    @Test("Formats 70358.64 as '70,358.64' with en_US locale pin")
    func localePin_producesEnUSFormat() {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true

        let result = f.string(from: NSDecimalNumber(string: "70358.64"))
        #expect(result == "70,358.64")
    }

    @Test("Formats 1234567.89 as '1,234,567.89' with en_US locale pin")
    func localePin_largeNumber_producesEnUSFormat() {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true

        let result = f.string(from: NSDecimalNumber(string: "1234567.89"))
        #expect(result == "1,234,567.89")
    }

    @Test("Formats quantity 0.0042 as '0.0042' with en_US locale pin (4 fraction digits)")
    func localePin_qtyFormatter_producesEnUSFormat() {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 4
        f.maximumFractionDigits = 4
        f.usesGroupingSeparator = false

        let result = f.string(from: NSDecimalNumber(string: "0.0042"))
        #expect(result == "0.0042")
    }
}
