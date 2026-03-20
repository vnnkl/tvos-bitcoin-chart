import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Ticker Data Parsing Tests

@Suite("STRC Ticker Data Parsing")
struct STRCTickerDataTests {

    // Minimal but complete fixture matching the real /api/ticker-data shape.
    // Includes nested summary, dividends, latest, marketStatus, and btcPrice.
    let tickerFixtureJSON = """
    {
      "success": true,
      "updated": "2026-03-20T05:00:00.000Z",
      "btcPrice": 84321.50,
      "marketStatus": {
        "market": "open",
        "afterHours": false,
        "earlyHours": false
      },
      "tickers": {
        "STRC": {
          "ipoDate": "2024-06-17",
          "closePrice": 18.45,
          "previousClose": 18.20,
          "extendedHoursPrice": 18.50,
          "extendedHoursChange": 0.05,
          "extendedHoursChangePercent": 0.27,
          "latest": {
            "date": "2026-03-20",
            "close": 18.45,
            "high": 18.90,
            "low": 17.80,
            "volume": 2450000,
            "source": "regular"
          },
          "summary": {
            "annualizedDividend": 2.12,
            "currentYield": 11.49,
            "exDividendDate": "2026-03-27",
            "rateSource": "declared"
          },
          "dividends": {
            "current": {
              "exDate": "2026-03-27",
              "payDate": "2026-04-07",
              "amount": 0.53,
              "annualizedRate": 2.12,
              "recordDate": "2026-03-28",
              "declarationDate": "2026-03-15"
            },
            "history": [
              {
                "exDate": "2025-12-26",
                "payDate": "2026-01-06",
                "amount": 0.53,
                "annualizedRate": 2.12,
                "recordDate": "2025-12-27",
                "declarationDate": "2025-12-15"
              }
            ]
          }
        }
      }
    }
    """.data(using: .utf8)!

    @Test("Decodes success flag")
    func decodesSuccess() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        #expect(response.success == true)
    }

    @Test("Decodes updated timestamp")
    func decodesUpdated() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        #expect(response.updated == "2026-03-20T05:00:00.000Z")
    }

    @Test("Decodes BTC price as Double")
    func decodesBtcPrice() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        #expect(response.btcPrice == 84321.50)
    }

    @Test("Decodes market status")
    func decodesMarketStatus() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        #expect(response.marketStatus.market == "open")
        #expect(response.marketStatus.afterHours == false)
        #expect(response.marketStatus.earlyHours == false)
    }

    @Test("Decodes STRC ticker closePrice")
    func decodesStrcClosePrice() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        let strc = try #require(response.tickers["STRC"])
        #expect(strc.closePrice == 18.45)
    }

    @Test("Decodes STRC ticker previousClose")
    func decodesStrcPreviousClose() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        let strc = try #require(response.tickers["STRC"])
        #expect(strc.previousClose == 18.20)
    }

    @Test("Decodes STRC latest price fields")
    func decodesLatestPrice() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        let strc = try #require(response.tickers["STRC"])
        #expect(strc.latest.close == 18.45)
        #expect(strc.latest.high == 18.90)
        #expect(strc.latest.low == 17.80)
        #expect(strc.latest.volume == 2_450_000)
        #expect(strc.latest.source == "regular")
    }

    @Test("Decodes STRC summary yield and ex-dividend date")
    func decodesTickerSummary() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        let strc = try #require(response.tickers["STRC"])
        #expect(strc.summary.currentYield == 11.49)
        #expect(strc.summary.exDividendDate == "2026-03-27")
        #expect(strc.summary.annualizedDividend == 2.12)
    }

    @Test("Decodes current dividend record")
    func decodesCurrentDividend() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        let strc = try #require(response.tickers["STRC"])
        let current = try #require(strc.dividends.current)
        #expect(current.exDate == "2026-03-27")
        #expect(current.payDate == "2026-04-07")
        #expect(current.amount == 0.53)
    }

    @Test("Decodes dividend history array")
    func decodesDividendHistory() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        let strc = try #require(response.tickers["STRC"])
        let history = try #require(strc.dividends.history)
        #expect(history.count == 1)
        #expect(history[0].exDate == "2025-12-26")
    }

    @Test("Decodes extended hours optional fields")
    func decodesExtendedHoursFields() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: tickerFixtureJSON)
        let strc = try #require(response.tickers["STRC"])
        #expect(strc.extendedHoursPrice == 18.50)
        #expect(strc.extendedHoursChange == 0.05)
        #expect(strc.extendedHoursChangePercent == 0.27)
    }

    // R029: SATA ticker returns btcCorrelation object with null current and no windowDays key.
    // JSONDecoder must not throw — both inner fields are optional.
    @Test("SATA btcCorrelation with null current and missing windowDays decodes")
    func decodesSataBtcCorrelationNullFields() throws {
        let json = """
        {
          "success": true,
          "updated": "2026-03-20T05:00:00.000Z",
          "btcPrice": 84000.0,
          "marketStatus": { "market": "open", "afterHours": false, "earlyHours": false },
          "tickers": {
            "SATA": {
              "ipoDate": "2024-01-01",
              "closePrice": 5.00,
              "previousClose": 4.90,
              "latest": {
                "date": "2026-03-20",
                "close": 5.00,
                "high": 5.10,
                "low": 4.80,
                "volume": 500000,
                "source": "regular"
              },
              "summary": {},
              "dividends": {},
              "btcCorrelation": {
                "current": null,
                "history": []
              }
            }
          }
        }
        """.data(using: .utf8)!
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: json)
        let sata = try #require(response.tickers["SATA"])
        // btcCorrelation wrapper is present
        let corr = try #require(sata.btcCorrelation)
        // Inner fields must be nil, not cause a decode failure
        #expect(corr.current == nil)
        #expect(corr.windowDays == nil)
    }

    @Test("Missing optional fields decode without error")
    func decodesWithMissingOptionalFields() throws {
        let json = """
        {
          "success": true,
          "updated": "2026-03-20T05:00:00.000Z",
          "btcPrice": 84000.0,
          "marketStatus": { "market": "closed", "afterHours": true, "earlyHours": false },
          "tickers": {
            "STRC": {
              "ipoDate": "2024-06-17",
              "closePrice": 18.0,
              "previousClose": 17.5,
              "latest": {
                "date": "2026-03-20",
                "close": 18.0,
                "high": 18.5,
                "low": 17.5,
                "volume": 1000000,
                "source": "regular"
              },
              "summary": {},
              "dividends": {}
            }
          }
        }
        """.data(using: .utf8)!
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCTickerResponse.self, from: json)
        let strc = try #require(response.tickers["STRC"])
        // Optional fields should be nil, not crash
        #expect(strc.extendedHoursPrice == nil)
        #expect(strc.btcCorrelation == nil)
        #expect(strc.history == nil)
        #expect(strc.summary.currentYield == nil)
        #expect(strc.summary.exDividendDate == nil)
        #expect(strc.dividends.current == nil)
        #expect(strc.dividends.history == nil)
    }
}

// MARK: - SEC Filings Parsing Tests

@Suite("STRC SEC Filings Parsing")
struct STRCSECFilingsTests {

    let filingsFixtureJSON = """
    {
      "success": true,
      "filings": [
        {
          "ticker": "STRC",
          "filedDate": "2026-03-16",
          "url": "https://www.sec.gov/Archives/edgar/data/2011238/000201123826000042",
          "period": "Mar 8 - Mar 14",
          "periodStart": "2026-03-08",
          "periodEnd": "2026-03-14",
          "sharesSold": 11818467,
          "netProceeds": 1180400000,
          "btcPurchased": null,
          "avgBtcPrice": 70194,
          "offeringType": "atm"
        },
        {
          "ticker": "STRC",
          "filedDate": "2026-01-10",
          "url": "https://www.sec.gov/Archives/edgar/data/2011238/000201123826000001",
          "period": null,
          "periodStart": null,
          "periodEnd": null,
          "sharesSold": 5000000,
          "netProceeds": 500000000,
          "btcPurchased": null,
          "avgBtcPrice": 95000,
          "offeringType": "ipo"
        }
      ]
    }
    """.data(using: .utf8)!

    @Test("Decodes success flag")
    func decodesSuccess() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: filingsFixtureJSON)
        #expect(response.success == true)
    }

    @Test("Decodes correct number of filings")
    func decodesFilingCount() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: filingsFixtureJSON)
        #expect(response.filings.count == 2)
    }

    @Test("Decodes first filing ticker and date")
    func decodesFirstFilingTickerAndDate() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: filingsFixtureJSON)
        let filing = response.filings[0]
        #expect(filing.ticker == "STRC")
        #expect(filing.filedDate == "2026-03-16")
    }

    @Test("Decodes sharesSold and netProceeds")
    func decodesSharesAndProceeds() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: filingsFixtureJSON)
        let filing = response.filings[0]
        #expect(filing.sharesSold == 11_818_467)
        #expect(filing.netProceeds == 1_180_400_000)
    }

    @Test("Decodes avgBtcPrice and offeringType")
    func decodesAvgPriceAndType() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: filingsFixtureJSON)
        let filing = response.filings[0]
        #expect(filing.avgBtcPrice == 70_194)
        #expect(filing.offeringType == "atm")
    }

    @Test("null btcPurchased decodes as nil")
    func decodesNullBtcPurchased() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: filingsFixtureJSON)
        #expect(response.filings[0].btcPurchased == nil)
        #expect(response.filings[1].btcPurchased == nil)
    }

    @Test("Null period fields decode without error")
    func decodesNullPeriodFields() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: filingsFixtureJSON)
        let filing = response.filings[1]
        #expect(filing.period == nil)
        #expect(filing.periodStart == nil)
        #expect(filing.periodEnd == nil)
    }

    @Test("Decodes period string when present")
    func decodesPeriodString() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: filingsFixtureJSON)
        #expect(response.filings[0].period == "Mar 8 - Mar 14")
    }

    @Test("Decodes SEC filing URL")
    func decodesUrl() throws {
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: filingsFixtureJSON)
        #expect(response.filings[0].url.hasPrefix("https://www.sec.gov"))
    }
}

// MARK: - Computed Property Tests

@Suite("SECFiling.estimatedBTCPurchased")
struct SECFilingComputedTests {

    @Test("Correctly derives BTC from proceeds and avg price")
    func derivesCorrectBTCEstimate() throws {
        let filing = SECFiling(
            ticker: "STRC",
            filedDate: "2026-03-16",
            url: "https://sec.gov",
            period: nil,
            periodStart: nil,
            periodEnd: nil,
            sharesSold: 11_818_467,
            netProceeds: 1_180_400_000,
            btcPurchased: nil,
            avgBtcPrice: 70_194,
            offeringType: "atm"
        )
        let estimated = filing.estimatedBTCPurchased
        // 1_180_400_000 / 70_194 ≈ 16,816.5
        #expect(estimated > 16_000.0)
        #expect(estimated < 18_000.0)
    }

    @Test("Returns exact value matching manual division")
    func returnsExactDivision() throws {
        let filing = SECFiling(
            ticker: "STRC",
            filedDate: "2026-01-01",
            url: "https://sec.gov",
            period: nil,
            periodStart: nil,
            periodEnd: nil,
            sharesSold: 1000,
            netProceeds: 1_000_000,
            btcPurchased: nil,
            avgBtcPrice: 100_000,
            offeringType: "atm"
        )
        #expect(filing.estimatedBTCPurchased == 10.0)
    }

    @Test("Returns 0 when avgBtcPrice is 0 (guard clause)")
    func returnsZeroOnZeroAvgPrice() throws {
        let filing = SECFiling(
            ticker: "STRC",
            filedDate: "2026-01-01",
            url: "https://sec.gov",
            period: nil,
            periodStart: nil,
            periodEnd: nil,
            sharesSold: 1000,
            netProceeds: 500_000,
            btcPurchased: nil,
            avgBtcPrice: 0,
            offeringType: "atm"
        )
        #expect(filing.estimatedBTCPurchased == 0.0)
    }

    @Test("estimatedBTCPurchased decodes and computes correctly from JSON fixture")
    func computesFromDecoded() throws {
        let json = """
        {
          "success": true,
          "filings": [{
            "ticker": "STRC",
            "filedDate": "2026-03-16",
            "url": "https://sec.gov",
            "period": null,
            "periodStart": null,
            "periodEnd": null,
            "sharesSold": 100,
            "netProceeds": 9500000,
            "btcPurchased": null,
            "avgBtcPrice": 95000,
            "offeringType": "atm"
          }]
        }
        """.data(using: .utf8)!
        let decoder = makeDecoder()
        let response = try decoder.decode(STRCFilingsResponse.self, from: json)
        let filing = response.filings[0]
        #expect(filing.estimatedBTCPurchased == 100.0)
    }
}

// MARK: - Helpers

private func makeDecoder() -> JSONDecoder {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
}
