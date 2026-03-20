import Foundation
import OSLog

private let logger = Logger(subsystem: "com.bitcointerminal.strc", category: "STRCService")

/// REST service for the `strc.live` public API.
///
/// Two endpoints are supported:
/// - `GET /api/ticker-data` → `STRCTickerResponse`
/// - `GET /api/sec-filings` → `STRCFilingsResponse`
///
/// Both are unauthenticated, read-only JSON endpoints that return a `success` flag.
///
/// **Observability:** All fetches are logged under subsystem `"com.bitcointerminal.strc"`,
/// category `"STRCService"`. Inspect live with:
/// ```
/// log stream --predicate 'subsystem == "com.bitcointerminal.strc"'
/// ```
final class STRCService: @unchecked Sendable {

    // MARK: - Configuration

    private let baseURL = "https://strc.live"
    private let urlSession: URLSession
    private let decoder: JSONDecoder

    // MARK: - Init

    /// - Parameter urlSession: Injected for testability; defaults to `.shared`.
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = d
    }

    // MARK: - Fetch Ticker Data

    /// Fetches the full ticker snapshot from `/api/ticker-data`.
    ///
    /// - Returns: A decoded `STRCTickerResponse` on success.
    /// - Throws: `URLError(.badURL)` if the URL is malformed,
    ///           `URLError(.badServerResponse)` on non-2xx HTTP status.
    func fetchTickerData() async throws -> STRCTickerResponse {
        guard let url = URL(string: "\(baseURL)/api/ticker-data") else {
            throw URLError(.badURL)
        }
        logger.info("Fetching ticker data from \(url.absoluteString)")
        let (data, response) = try await urlSession.data(from: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            logger.error("Ticker data fetch failed — HTTP \(http.statusCode)")
            throw URLError(.badServerResponse)
        }

        let result = try decoder.decode(STRCTickerResponse.self, from: data)
        logger.info("Ticker data fetched successfully — updated: \(result.updated), btcPrice: \(result.btcPrice)")
        return result
    }

    // MARK: - Fetch SEC Filings

    /// Fetches all SEC 8-K ATM filings from `/api/sec-filings`.
    ///
    /// - Returns: A decoded `STRCFilingsResponse` on success.
    /// - Throws: `URLError(.badURL)` if the URL is malformed,
    ///           `URLError(.badServerResponse)` on non-2xx HTTP status.
    func fetchFilings() async throws -> STRCFilingsResponse {
        guard let url = URL(string: "\(baseURL)/api/sec-filings") else {
            throw URLError(.badURL)
        }
        logger.info("Fetching SEC filings from \(url.absoluteString)")
        let (data, response) = try await urlSession.data(from: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            logger.error("SEC filings fetch failed — HTTP \(http.statusCode)")
            throw URLError(.badServerResponse)
        }

        let result = try decoder.decode(STRCFilingsResponse.self, from: data)
        logger.info("SEC filings fetched successfully — \(result.filings.count) filing(s)")
        return result
    }
}
