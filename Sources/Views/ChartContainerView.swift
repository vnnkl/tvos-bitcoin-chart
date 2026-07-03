import SwiftUI

/// Full trading terminal layout — industrial precision for a 55"+ screen.
///
/// ```
/// ┌──────────────────────────────────────────────────────────────────────┐
/// │ [₿] BTC/USDT  71,234.56 [+2.41%] │ 1m 3m … 1w │ ⊖ ⊕ Candle Line ● │ ← header
/// │  Regime: Balanced flow …             24H HIGH │ 24H LOW │ 24H VOL   │ ← strip
/// ├──────────────────────────────────────────┬───────────────────────────┤
/// │                                          │ ╭─ ORDER BOOK ─────────╮ │
/// │  Candlestick / Line chart                │ │ bid/ask gauge         │ │
/// │  + depth heatmap behind                  │ │ depth-bar ladder      │ │
/// │  + volume bars (bottom 18%)              │ │ cumulative depth      │ │
/// │                                          │ ╰───────────────────────╯ │
/// │                                          │ ╭─ TRADES ─────────────╮ │
/// │                                          │ │ buy/sell pressure     │ │
/// │                                          │ │ live feed             │ │
/// └──────────────────────────────────────────┴─╰───────────────────────╯─┘
///                                            ▲ 420 pt sidebar
/// ```
struct ChartContainerView: View {

    @Bindable var viewModel: ChartViewModel
    var indicatorSettings: IndicatorSettings
    var alertStore: AlertStore?

    @Namespace private var headerFocusScope

    /// Direction of the most recent price tick: +1 up, −1 down, 0 before first tick.
    /// Drives the Binance-style persistent tint on the big price readout.
    @State private var tickDirection = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {

                // ── Header bar ─────────────────────────────────────
                headerBar
                    .focusScope(headerFocusScope)
                    .focusSection()
                    .padding(.bottom, 10)

                // ── Main content ───────────────────────────────────
                HStack(spacing: 12) {

                    // Left: chart + volume
                    VStack(spacing: 0) {
                        chartArea
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onAppear {
                                viewModel.exitExploration()
                            }

                        VolumeBarView(klines: viewModel.visibleKlines)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: geometry.size.height * AppTheme.volumeHeightRatio
                            )
                            .padding(.top, 4)

                        indicatorPanels
                    }

                    // Right: sidebar
                    sidebar
                        .frame(width: AppTheme.sidebarWidth)
                        .focusSection()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
        .background(AppTheme.background.ignoresSafeArea())
        .onChange(of: viewModel.klineStore.currentPrice) { oldPrice, newPrice in
            if newPrice > oldPrice { tickDirection = 1 }
            else if newPrice < oldPrice { tickDirection = -1 }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 10) {
                if let alert = viewModel.triggeredAlert {
                    AlertBannerView(alert: alert)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let transition = viewModel.regimeTransition {
                    MarketRegimeBannerView(regime: transition.regime)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if viewModel.connectionHealth == .reconnecting {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Reconnecting to Binance…")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppTheme.stateReconnecting.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, AppTheme.edgePadding)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.triggeredAlert?.id)
        .animation(.easeInOut(duration: 0.3), value: viewModel.regimeTransition?.id)
        .animation(.easeInOut(duration: 0.3), value: viewModel.connectionHealth)
    }

    // MARK: - Header bar

    @ViewBuilder
    private var headerBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                identityBlock

                Spacer(minLength: 24)

                TimeframeSelectorView(
                    activeInterval: $viewModel.currentInterval,
                    onSelect: { viewModel.switchInterval($0) },
                    focusScope: headerFocusScope
                )
                .frame(maxWidth: 720)
                .prefersDefaultFocus(true, in: headerFocusScope)

                Spacer(minLength: 24)

                HStack(spacing: 16) {
                    zoomControls
                    chartModeToggle
                    ConnectionStatusView(state: viewModel.connectionHealth)
                }
            }

            // Context strip: market regime (left) + 24h session stats (right).
            HStack(spacing: 10) {
                MarketRegimeStripView(regime: viewModel.marketRegime)
                statsStrip
            }
        }
    }

    /// Brand/identity cluster: ₿ badge, pair + venue, live price, 24h change pill.
    private var identityBlock: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.16))
                Image(systemName: "bitcoinsign")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("BTC / USDT")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("BINANCE · SPOT")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Text(formattedPrice)
                .font(.system(size: 44, weight: .heavy, design: .monospaced))
                .foregroundStyle(priceColor)
                .contentTransition(.numericText())

            changePill
        }
    }

    private var changePill: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.klineStore.priceChange24h >= 0
                  ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 18, weight: .bold))
            Text(formattedChange)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .contentTransition(.numericText())
        }
        .foregroundStyle(changeColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(changeColor.opacity(0.14)))
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            Button { viewModel.zoomOut() } label: {
                IconPillLabel(systemImage: "minus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .disabled(viewModel.zoomLevel <= -3)
            .opacity(viewModel.zoomLevel <= -3 ? 0.35 : 1)

            Button { viewModel.zoomIn() } label: {
                IconPillLabel(systemImage: "plus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .disabled(viewModel.zoomLevel >= 5)
            .opacity(viewModel.zoomLevel >= 5 ? 0.35 : 1)
        }
    }

    /// Right-aligned 24h session statistics, styled to match the regime strip.
    @ViewBuilder
    private var statsStrip: some View {
        if let stats = viewModel.klineStore.stats24h {
            HStack(spacing: 20) {
                StatBlock(label: "24h High", value: formatStatPrice(stats.high), tint: AppTheme.candleUp)
                statsDivider
                StatBlock(label: "24h Low", value: formatStatPrice(stats.low), tint: AppTheme.candleDown)
                statsDivider
                StatBlock(label: "24h Vol", value: "\(AppFormatters.compact(stats.volume)) BTC")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                    .fill(AppTheme.surface)
            )
        }
    }

    private var statsDivider: some View {
        Rectangle()
            .fill(AppTheme.separator)
            .frame(width: 1, height: 30)
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        GeometryReader { geo in
            let orderBookHeight = geo.size.height * 0.58

            VStack(spacing: 12) {
                orderBookPanel
                    .frame(height: orderBookHeight)

                tradesPanel
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private var orderBookPanel: some View {
        let imbalance = viewModel.orderBookStore.snapshots.last?.bidImbalance ?? 0.5

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                PanelHeaderLabel(text: "Order Book", icon: "list.bullet.rectangle")
                Spacer()
                Text("\(Int((imbalance * 100).rounded()))% BID")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(imbalance >= 0.5 ? AppTheme.candleUp : AppTheme.candleDown)
            }

            RatioBar(ratio: imbalance)

            GeometryReader { inner in
                VStack(alignment: .leading, spacing: 0) {
                    OrderBookLadderView(orderBookStore: viewModel.orderBookStore)
                        .frame(maxWidth: .infinity)
                        .frame(height: inner.size.height * 0.66)
                        .clipped()

                    Rectangle()
                        .fill(AppTheme.separator)
                        .frame(height: 1)
                        .padding(.vertical, 6)

                    DepthChartView(snapshot: viewModel.orderBookStore.snapshots.last)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
        }
        .terminalPanel(padding: 14)
    }

    private var tradesPanel: some View {
        let buyRatio = viewModel.tradeStore.buyVolumeRatio()

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                PanelHeaderLabel(text: "Trades", icon: "arrow.left.arrow.right")
                Spacer()
                Text("\(Int((buyRatio * 100).rounded()))% BUY")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(buyRatio >= 0.5 ? AppTheme.candleUp : AppTheme.candleDown)
            }

            RatioBar(ratio: buyRatio)

            TradesFeedView(tradeStore: viewModel.tradeStore)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .terminalPanel(padding: 14)
    }

    // MARK: - Chart mode toggle

    @ViewBuilder
    private var chartModeToggle: some View {
        HStack(spacing: 8) {
            chartModeButton(.candlestick, label: "Candle")
            chartModeButton(.line,        label: "Line")
        }
    }

    @ViewBuilder
    private func chartModeButton(_ mode: ChartMode, label: String) -> some View {
        Button {
            viewModel.chartMode = mode
        } label: {
            PillLabel(text: label, isActive: viewModel.chartMode == mode)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    // MARK: - Chart area

    @ViewBuilder
    private var chartArea: some View {
        if viewModel.error != nil && viewModel.klineStore.klines.isEmpty {
            chartErrorView
        } else {
            chartZStack
        }
    }

    private var chartErrorView: some View {
        VStack(spacing: AppTheme.sectionSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.candleDown)
            Text("Data temporarily unavailable")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Check your network connection.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.edgePadding)
    }

    @ViewBuilder
    private var chartZStack: some View {
        let klines = viewModel.visibleKlines
        let (pMin, pRange) = priceExtents(klines)

        VStack(spacing: 0) {
            // Chart canvas + price axis side-by-side
            HStack(spacing: 0) {
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

                    IndicatorOverlayView(
                        klines: klines,
                        indicatorSettings: indicatorSettings,
                        priceMin: pMin,
                        priceRange: pRange
                    )

                    AlertOverlayView(
                        alerts: alertStore?.alerts.filter { $0.isEnabled } ?? [],
                        priceMin: pMin,
                        priceRange: pRange
                    )

                    if viewModel.isExploring,
                       let idx = viewModel.crosshairIndex,
                       !klines.isEmpty {
                        CrosshairOverlayView(
                            klines: klines,
                            crosshairIndex: idx,
                            priceMin: pMin,
                            priceRange: pRange
                        )
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(AppTheme.textPrimary)
                            .scaleEffect(1.5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Price Y-axis panel on the right edge
                PriceAxisView(priceMin: pMin, priceRange: pRange)
                    .frame(width: AppTheme.priceAxisWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Time X-axis bar below chart + price axis
            TimeAxisView(klines: klines, currentInterval: viewModel.currentInterval)
                .frame(height: AppTheme.timeAxisHeight)
        }
    }

    @ViewBuilder
    private var indicatorPanels: some View {
        let klines = viewModel.visibleKlines

        if indicatorSettings.showRSI14 || indicatorSettings.showMACD {
            VStack(spacing: 6) {
                if indicatorSettings.showRSI14 {
                    RSIGaugeView(klines: klines)
                        .frame(height: 76)
                }

                if indicatorSettings.showMACD {
                    MACDPanelView(klines: klines)
                        .frame(height: 110)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Formatting

    private var formattedPrice: String {
        AppFormatters.price.string(from: viewModel.klineStore.currentPrice as NSDecimalNumber)
            ?? "\(viewModel.klineStore.currentPrice)"
    }

    private var formattedChange: String {
        let change = viewModel.klineStore.priceChange24h
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(AppFormatters.change.string(from: change as NSDecimalNumber) ?? "\(change)")%"
    }

    private func formatStatPrice(_ value: Decimal) -> String {
        AppFormatters.axisPrice.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    /// Tint for the big price readout: follows the direction of the last tick.
    private var priceColor: Color {
        if tickDirection > 0 { return AppTheme.candleUp }
        if tickDirection < 0 { return AppTheme.candleDown }
        return AppTheme.textPrimary
    }

    private var changeColor: Color {
        viewModel.klineStore.priceChange24h >= 0 ? AppTheme.candleUp : AppTheme.candleDown
    }
}

#Preview {
    @Previewable @State var indicatorSettings = IndicatorSettings()

    ChartContainerView(viewModel: ChartViewModel(), indicatorSettings: indicatorSettings)
        .frame(width: 1920, height: 1080)
}
