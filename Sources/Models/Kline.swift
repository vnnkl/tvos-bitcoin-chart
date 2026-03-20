import Foundation

/// A single OHLCV candlestick bar.
/// Produced from either the Binance REST API (array-of-arrays) or the WebSocket
/// kline stream (nested `k` object). Prices use `Decimal` for exact representation.
struct Kline: Sendable {
    let openTime: Date
    let open: Decimal
    let high: Decimal
    let low: Decimal
    let close: Decimal
    let volume: Decimal
    let closeTime: Date
    /// `true` when the candle is complete (REST always returns `true`; WebSocket
    /// `x` field determines this for live candles).
    let isClosed: Bool
}

// MARK: - REST Array Format

/// Wraps the 12-element array Binance returns for each kline in the REST response.
///
/// Example element:
/// ```json
/// [1625097600000,"34000.00","35000.00","33500.00","34800.00","125.5",
///  1625097659999,"4366000.00",100,"62.5","2183000.00","0"]
/// ```
/// Index mapping:
/// 0 – open time (ms)
/// 1 – open price
/// 2 – high price
/// 3 – low price
/// 4 – close price
/// 5 – volume
/// 6 – close time (ms)
/// (remaining indices are ignored for now)
struct BinanceKlineREST: Decodable {
    let kline: Kline

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let openTimeMs = try container.decode(Int64.self)
        let openStr    = try container.decode(String.self)
        let highStr    = try container.decode(String.self)
        let lowStr     = try container.decode(String.self)
        let closeStr   = try container.decode(String.self)
        let volumeStr  = try container.decode(String.self)
        let closeTimeMs = try container.decode(Int64.self)

        guard
            let open   = Decimal(string: openStr),
            let high   = Decimal(string: highStr),
            let low    = Decimal(string: lowStr),
            let close  = Decimal(string: closeStr),
            let volume = Decimal(string: volumeStr)
        else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.unkeyedContainer(),
                debugDescription: "Could not parse price strings to Decimal"
            )
        }

        kline = Kline(
            openTime:  Date(timeIntervalSince1970: Double(openTimeMs) / 1000.0),
            open:      open,
            high:      high,
            low:       low,
            close:     close,
            volume:    volume,
            closeTime: Date(timeIntervalSince1970: Double(closeTimeMs) / 1000.0),
            isClosed:  true
        )
    }
}

// MARK: - WebSocket Event Format

/// Top-level WebSocket message for a kline stream event.
///
/// Example:
/// ```json
/// {"e":"kline","E":123456,"s":"BTCUSDT","k":{...}}
/// ```
struct BinanceKlineEvent: Decodable {
    let kline: Kline

    private enum CodingKeys: String, CodingKey {
        case eventType = "e"
        case data = "k"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(BinanceKlineData.self, forKey: .data)
        kline = data.kline
    }
}

/// The nested `k` object inside a WebSocket kline event.
private struct BinanceKlineData: Decodable {
    let kline: Kline

    private enum CodingKeys: String, CodingKey {
        case openTimeMs  = "t"
        case closeTimeMs = "T"
        case open        = "o"
        case high        = "h"
        case low         = "l"
        case close       = "c"
        case volume      = "v"
        case isClosed    = "x"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let openTimeMs  = try container.decode(Int64.self, forKey: .openTimeMs)
        let closeTimeMs = try container.decode(Int64.self, forKey: .closeTimeMs)
        let openStr     = try container.decode(String.self, forKey: .open)
        let highStr     = try container.decode(String.self, forKey: .high)
        let lowStr      = try container.decode(String.self, forKey: .low)
        let closeStr    = try container.decode(String.self, forKey: .close)
        let volumeStr   = try container.decode(String.self, forKey: .volume)
        let isClosed    = try container.decode(Bool.self,   forKey: .isClosed)

        guard
            let open   = Decimal(string: openStr),
            let high   = Decimal(string: highStr),
            let low    = Decimal(string: lowStr),
            let close  = Decimal(string: closeStr),
            let volume = Decimal(string: volumeStr)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .open,
                in: container,
                debugDescription: "Could not parse price strings to Decimal"
            )
        }

        kline = Kline(
            openTime:  Date(timeIntervalSince1970: Double(openTimeMs)  / 1000.0),
            open:      open,
            high:      high,
            low:       low,
            close:     close,
            volume:    volume,
            closeTime: Date(timeIntervalSince1970: Double(closeTimeMs) / 1000.0),
            isClosed:  isClosed
        )
    }
}
