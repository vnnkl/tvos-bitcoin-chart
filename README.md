# Bitcoin Terminal for Apple TV

A real-time Bitcoin trading terminal for tvOS. Live candlestick charts, order book, trade feed, and STRC accumulation dashboard — all running natively on Apple TV.

![tvOS](https://img.shields.io/badge/platform-tvOS%2017%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)

## Features

**Chart Tab**
- Live candlestick and line charts via Binance WebSocket
- 13 timeframes: 1m, 3m, 5m, 15m, 30m, 1h, 2h, 4h, 6h, 12h, 1d, 3d, 1w
- Order book depth ladder with bid/ask spread
- Depth chart visualization
- Real-time trade feed with color-coded buy/sell
- Depth heatmap overlay behind candlesticks
- Crosshair exploration mode (press Play/Pause, navigate with D-pad)
- Zoom in/out with geometric scaling
- Price and time axes with auto-scaling tick intervals
- Price alert overlays on the chart canvas
- Alert banners when thresholds are crossed
- Connection status indicator with auto-reconnect

**STRC Tab**
- Live ticker data from strc.live API
- ATM (At-The-Market) active/standby status
- BTC accumulation summary from SEC 8-K filings
- SEC filings table

**Settings Tab**
- Switch between Binance (live) and Stub (demo) data sources
- Configurable default timeframe (persisted across launches)
- Price alert CRUD: add above/below current price, re-arm, delete

## Architecture

```
Sources/
├── App/                    # App entry point, root ContentView with native TabView
├── Models/                 # Data types: Kline, AggTrade, OrderBookSnapshot, PriceAlert, STRC models
├── Services/               # Network layer
│   ├── ExchangeDataService # Protocol — abstracts any exchange
│   ├── BinanceService      # REST + 3 independent WebSocket streams
│   ├── StubExchangeService # Fixture data for offline development
│   ├── STRCService         # strc.live JSON API client
│   └── WebSocketManager    # URLSessionWebSocketTask wrapper with reconnect
├── Stores/                 # Reactive data stores: KlineStore, OrderBookStore, TradeStore, AlertStore, STRCStore
├── ViewModels/             # ChartViewModel (orchestrator), STRCViewModel
├── Views/                  # SwiftUI views — all Canvas-based chart rendering
├── Theme/                  # AppTheme: colors, fonts, layout constants
└── Settings/               # AppSettings (UserDefaults persistence)
```

**Key design choices:**
- `ExchangeDataService` protocol allows swapping data sources without touching views
- Three independent WebSocket connections (klines, depth, trades) for resilient streaming
- `Decimal` arithmetic throughout for price precision (no floating-point drift)
- `@Observable` + `@MainActor` for thread-safe SwiftUI updates
- Swift 6 strict concurrency throughout
- Canvas-based rendering for chart views (no third-party charting libraries)
- Native tvOS `TabView` for system-standard navigation and focus management

## Requirements

- Xcode 16+ with tvOS SDK
- tvOS 17.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Setup

```bash
# Install XcodeGen (if not installed)
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open BitcoinTerminal.xcodeproj
```

Build and run on the Apple TV Simulator or a physical Apple TV.

### Command Line

```bash
# Build
xcodebuild build -scheme BitcoinTerminal -destination 'platform=tvOS Simulator,name=Apple TV'

# Run tests
xcodebuild test -scheme BitcoinTerminalTests -destination 'platform=tvOS Simulator,name=Apple TV'
```

## Siri Remote Controls

| Action | Control |
|--------|---------|
| Switch tabs | Swipe up to reveal tab bar, swipe left/right |
| Navigate timeframes | Swipe left/right on timeframe bar |
| Zoom in/out | Focus zoom buttons in header |
| Enter crosshair mode | Press Play/Pause |
| Move crosshair | D-pad left/right |
| Exit crosshair | Press Menu |
| Exit to tab bar | Press Menu (when not exploring) |

## Data Sources

- **Binance** — REST API for historical klines, WebSocket for live klines, order book depth (20 levels @ 100ms), and aggregate trades
- **strc.live** — JSON API for STRC ticker data and SEC 8-K filings
- **Stub** — Built-in fixture data for development and testing without network

## Tests

161 tests across 12 test suites covering models, stores, formatters, and view logic:

```
AggTradeTests, AlertStoreTests, DepthChartTests, FormatterTests,
KlineStoreTests, KlineTests, OrderBookSnapshotTests, OrderBookStoreTests,
STRCModelTests, StubExchangeServiceTests, TradeStoreTests, ZoomTests
```

## License

MIT
