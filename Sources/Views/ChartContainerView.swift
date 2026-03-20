import SwiftUI

/// Composes the full chart UI into a terminal-style layout:
///
/// ```
/// ┌────────────────────────────────────────────────────────┐
/// │  [price/change]  [── timeframe bar ──]  [mode][status] │  ← header row
/// ├──────────────────────────────────┬─────────────────────┤
/// │                                  │  Order Book         │
/// │  Chart (candlestick / line)      │  ─────────────────  │
/// │  + heatmap overlay               │  Recent Trades      │
/// │  + volume bars (bottom 20 %)     │                     │
/// └──────────────────────────────────┴─────────────────────┘
///                                    ▲ 340 pt fixed sidebar
/// ```
///
/// **Focus sections:** the timeframe bar, chart area, and sidebar each form an
/// independent `.focusSection()` so Siri Remote navigates between them cleanly.
///
/// Uses `@Bindable` so `$viewModel.chartMode` flows directly into the Picker.
struct ChartContainerView: View {

    @Bindable var viewModel: ChartViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {

                // ── Header row ─────────────────────────────────────────
                headerRow

                // ── Content: chart (left) + sidebar (right) ───────────
                HStack(alignment: .top, spacing: 0) {

                    // Left: chart + volume (fills remaining width)
                    VStack(spacing: 0) {
                        chartArea
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .focusSection()

                        VolumeBarView(klines: viewModel.klineStore.klines)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: geometry.size.height * AppTheme.volumeHeightRatio
                            )
                            .padding(.top, 12)
                    }

                    // Right: sidebar — order book + trades feed placeholders
                    sidebar
                        .frame(width: AppTheme.sidebarWidth)
                        .focusSection()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(AppTheme.edgePadding)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    // MARK: - Header row

    @ViewBuilder
    private var headerRow: some View {
        HStack(alignment: .center, spacing: AppTheme.sectionSpacing) {
            // Left: symbol + live price + 24 h change
            priceSection

            // Center: 13 timeframe buttons (fills remaining horizontal space)
            TimeframeSelectorView(
                activeInterval: $viewModel.currentInterval,
                onSelect: { viewModel.switchInterval($0) }
            )
            .frame(maxWidth: .infinity)

            // Right: chart mode toggle + connection indicator
            chartModeToggle
            ConnectionStatusView(state: viewModel.connectionState)
        }
        .padding(.bottom, AppTheme.sectionSpacing)
    }

    // MARK: - Sidebar (live order book + trades feed)

    @ViewBuilder
    private var sidebar: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {

                // ── Order Book (top 60 %) ─────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order Book")
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    OrderBookLadderView(orderBookStore: viewModel.orderBookStore)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: geo.size.height * 0.60)

                // ── Thin divider ──────────────────────────────────────
                Divider()
                    .background(AppTheme.textSecondary)
                    .padding(.vertical, 8)

                // ── Trades Feed (bottom 40 %) ─────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Trades")
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    TradesFeedView(tradeStore: viewModel.tradeStore)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: geo.size.height * 0.40)
            }
        }
        .padding(.leading, AppTheme.sectionSpacing)
    }

    // MARK: - Header: price section

    @ViewBuilder
    private var priceSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            // Symbol badge only (interval now lives in the timeframe selector)
            Text("BTC/USDT")
                .font(AppTheme.headlineFont)           // .title2
                .foregroundStyle(AppTheme.textPrimary)

            // Live price
            Text(formattedPrice)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())

            // 24 h change
            Text(formattedChange)
                .font(AppTheme.priceFont)              // .title
                .foregroundStyle(changeColor)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    // MARK: - Header: chart mode toggle

    @ViewBuilder
    private var chartModeToggle: some View {
        Picker("Chart Mode", selection: $viewModel.chartMode) {
            Text("Candlestick").tag(ChartMode.candlestick)
            Text("Line").tag(ChartMode.line)
        }
        .pickerStyle(.segmented)
        .frame(width: 360)
    }

    // MARK: - Chart area (ZStack: heatmap → chart → loading indicator)

    @ViewBuilder
    private var chartArea: some View {
        let klines = viewModel.klineStore.klines
        let (pMin, pRange) = priceExtents(klines)

        ZStack {
            DepthHeatmapView(
                snapshots: viewModel.orderBookStore.snapshots,
                klineCount: max(klines.count, 1),
                priceMin: pMin,
                priceRange: pRange
            )

            switch viewModel.chartMode {
            case .candlestick:
                CandlestickChartView(klines: klines)
            case .line:
                LineChartView(klines: klines)
            }

            if viewModel.isLoading {
                ProgressView()
                    .tint(AppTheme.textPrimary)
                    .scaleEffect(1.5)
            }
        }
    }

    // MARK: - Formatting helpers

    private var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter.string(from: viewModel.klineStore.currentPrice as NSDecimalNumber)
            ?? "\(viewModel.klineStore.currentPrice)"
    }

    private var formattedChange: String {
        let change = viewModel.klineStore.priceChange24h
        let sign = change >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(sign)\(formatter.string(from: change as NSDecimalNumber) ?? "\(change)")%"
    }

    private var changeColor: Color {
        viewModel.klineStore.priceChange24h >= 0 ? AppTheme.candleUp : AppTheme.candleDown
    }
}

#Preview {
    ChartContainerView(viewModel: ChartViewModel())
        .frame(width: 1920, height: 1080)
}
