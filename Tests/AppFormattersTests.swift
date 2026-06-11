import Testing
import Foundation
@testable import BitcoinTerminal

/// Locks the output of every shared formatter in `AppFormatters` to the exact
/// strings the view-local formatters produced before consolidation.
/// Any change to precision, locale, or grouping must show up here first.
@Suite("AppFormatters")
@MainActor
struct AppFormattersTests {

    private func str(_ formatter: NumberFormatter, _ value: String) -> String? {
        formatter.string(from: NSDecimalNumber(string: value))
    }

    // MARK: - Prices

    @Test func priceUsesTwoFractionDigitsAndGrouping() {
        #expect(str(AppFormatters.price, "70358.64") == "70,358.64")
        #expect(str(AppFormatters.price, "100") == "100.00")
    }

    @Test func axisPriceUsesWholeNumbersWithGrouping() {
        #expect(str(AppFormatters.axisPrice, "70358.4") == "70,358")
        #expect(str(AppFormatters.axisPrice, "5000") == "5,000")
    }

    @Test func changeUsesTwoFractionDigits() {
        #expect(str(AppFormatters.change, "1234.5") == "1,234.50")
        // NumberFormatter defaults to half-even rounding: -2.345 ties to the even digit.
        #expect(str(AppFormatters.change, "-2.345") == "-2.34")
    }

    // MARK: - Volume / quantity

    @Test func volumeUsesFourFractionDigitsWithGrouping() {
        #expect(str(AppFormatters.volume, "12345.6789") == "12,345.6789")
    }

    @Test func quantityUsesFourFractionDigitsWithoutGrouping() {
        #expect(str(AppFormatters.quantity, "0.0042") == "0.0042")
        #expect(str(AppFormatters.quantity, "12345.6789") == "12345.6789")
    }

    // MARK: - STRC dashboard

    @Test func btcHoldingsUsesTwoToFourFractionDigits() {
        #expect(str(AppFormatters.btcHoldings, "12345.6789") == "12,345.6789")
        #expect(str(AppFormatters.btcHoldings, "100") == "100.00")
    }

    @Test func btcFilingUsesTwoToThreeFractionDigits() {
        #expect(str(AppFormatters.btcFiling, "12345.6789") == "12,345.679")
        #expect(str(AppFormatters.btcFiling, "100") == "100.00")
    }

    @Test func sharesUsesWholeNumbersWithGrouping() {
        #expect(str(AppFormatters.shares, "1234567") == "1,234,567")
    }

    @Test func currencyUSDUsesTwoFractionDigits() {
        #expect(str(AppFormatters.currencyUSD, "70358.64") == "$70,358.64")
    }

    @Test func percentTreatsValuesAsAlreadyScaled() {
        #expect(str(AppFormatters.percent, "11.5") == "11.5%")
        #expect(str(AppFormatters.percent, "11.567") == "11.57%")
    }

    // MARK: - Dates (config locked; output depends on device time zone)

    @Test func tradeTimeUsesHoursMinutesSeconds() {
        #expect(AppFormatters.tradeTime.dateFormat == "HH:mm:ss")
    }

    @Test func axisIntradayUsesHoursMinutes() {
        #expect(AppFormatters.axisIntraday.dateFormat == "HH:mm")
    }

    @Test func axisDailyUsesMonthDay() {
        #expect(AppFormatters.axisDaily.dateFormat == "MMM dd")
    }

    @Test func tooltipTimeUsesShortTimeStyleOnly() {
        #expect(AppFormatters.tooltipTime.timeStyle == .short)
        #expect(AppFormatters.tooltipTime.dateStyle == .none)
    }
}
