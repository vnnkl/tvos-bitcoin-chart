import SwiftUI

/// Full trading terminal layout — industrial precision for a 55"+ screen.
///
/// ```
/// ┌──────────────────────────────────────────────────────────────────────┐
/// │  BTC/USDT  71,234.56  +2.41%  │  1m 3m 5m … 1w  │  Candlestick ● │ ← compact header
/// ├──────────────────────────────────────────┬────────────────────────────┤
/// │                                          │ PRICE       QTY    TOTAL │
/// │                                          │ 71,235.10   0.42   1.89  │ ← asks (red)
/// │  Candlestick / Line chart                │ 71,235.00   0.18   1.47  │
/// │  + depth heatmap behind                  │ ── Spread: 0.10 ──────── │
/// │  + volume bars (bottom 18%)              │ 71,234.90   0.55   2.01  │ ← bids (green)
/// │                                          │ 71,234.80   0.33   1.46  │
/// │                                          ├──────────────────────────│
/// │                                          │ TIME      PRICE     QTY  │
/// │                                          │ 09:41:23  71235.1  0.02  │ ← trades
/// └──────────────────────────────────────────┴────────────────────────────┘
///                                            ▲ 420 pt sidebar
/// ```
struct ChartContainerView: View {

    @Bindable var viewModel: ChartViewModel
    var alertStore: AlertStore?

    @FocusState private var chartFocused: Bool
    @FocusState private var focusedMode: ChartMode?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {

                // ── Header bar ─────────────────────────────────────
                headerBar
                    .padding(.bottom, 8)

                // Thin separator below header
                Rectangle()
                    .fill(AppTheme.separator)
                    .frame(height: 1)

                // ── Main content ───────────────────────────────────
                HStack(spacing: 0) {

                    // Left: chart + volume
                    VStack(spacing: 0) {
                        chartArea
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        chartFocused
                                            ? AppTheme.textSecondary.opacity(0.4)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .focusable()
                            .focused($chartFocused)
                            .focusSection()
                            .onPlayPauseCommand {
                                if viewModel.isExploring {
                                    viewModel.exitExploration()
                                } else {
                                    viewModel.enterExploration()
                                }
                            }
                            .onMoveCommand { direction in
                                if viewModel.isExploring {
                                    viewModel.moveCrosshair(direction)
                                } else if direction == .left || direction == .right {
                                    viewModel.enterExploration()
                                    viewModel.moveCrosshair(direction)
                                }
                            }
                            .onExitCommand {
                                viewModel.exitExploration()
                            }

                        VolumeBarView(klines: viewModel.visibleKlines)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: geometry.size.height * AppTheme.volumeHeightRatio
                            )
                            .padding(.top, 4)
                    }

                    // Vertical separator
                    Rectangle()
                        .fill(AppTheme.separator)
                        .frame(width: 1)
                        .padding(.vertical, 4)

                    // Right: sidebar
                    sidebar
                        .frame(width: AppTheme.sidebarWidth)
                        .focusSection()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 8)
            }
            .padding(.horizontal, AppTheme.edgePadding)
            .padding(.vertical, 40)
        }
        .background(AppTheme.background.ignoresSafeArea())
        // ── Alert banner ──
        .overlay(alignment: .top) {
            if let alert = viewModel.triggeredAlert {
                AlertBannerView(alert: alert)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, AppTheme.edgePadding)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.triggeredAlert?.id)
        // ── Reconnection banner ──
        .overlay(alignment: .top) {
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
                .padding(.top, AppTheme.edgePadding + 56)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.connectionHealth)
    }

    // MARK: - Header bar (single compact row)

    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: 0) {
            // ── Left: symbol + price + change ──
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("BTC/USDT")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(formattedPrice)
                    .font(.system(size: 44, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .contentTransition(.numericText())

                Text(formattedChange)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(changeColor)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 24)

            // ── Center: timeframe selector ──
            TimeframeSelectorView(
                activeInterval: $viewModel.currentInterval,
                onSelect: { viewModel.switchInterval($0) }
            )
            .frame(maxWidth: 720)

            Spacer(minLength: 24)

            // ── Right: zoom buttons + mode toggle + status ──
            HStack(spacing: 16) {
                // Zoom out / zoom in
                HStack(spacing: 8) {
                    Button { viewModel.zoomOut() } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(minWidth: 52, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.12)))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.zoomLevel <= -3)

                    Button { viewModel.zoomIn() } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(minWidth: 52, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.12)))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.zoomLevel >= 5)
                }

                chartModeToggle
                ConnectionStatusView(state: viewModel.connectionHealth)
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                // ── Order Book (top ~55%) ──
                VStack(alignment: .leading, spacing: 6) {
                    Text("ORDER BOOK")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textMuted)
                        .tracking(2)

                    OrderBookLadderView(orderBookStore: viewModel.orderBookStore)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: geo.size.height * 0.58)
                .clipped()

                // ── Separator ──
                Rectangle()
                    .fill(AppTheme.separator)
                    .frame(height: 1)
                    .padding(.vertical, 6)

                // ── Trades Feed (bottom ~45%) ──
                VStack(alignment: .leading, spacing: 6) {
                    Text("TRADES")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textMuted)
                        .tracking(2)

                    TradesFeedView(tradeStore: viewModel.tradeStore)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipped()
            }
        }
        .padding(.leading, 16)
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
        let isActive  = viewModel.chartMode == mode
        let isFocused = focusedMode == mode

        Button {
            viewModel.chartMode = mode
        } label: {
            Text(label)
                .font(.system(size: 24, weight: isActive ? .bold : .medium, design: .monospaced))
                .foregroundStyle(isActive ? .black : AppTheme.textPrimary)
                .frame(minWidth: 64, minHeight: 52)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? AppTheme.candleUp : Color(white: 0.12))
                )
        }
        .buttonStyle(.plain)
        .focused($focusedMode, equals: mode)
        .scaleEffect(isFocused ? 1.15 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
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

    // MARK: - Formatting

    private static let priceFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    private static let changeFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private var formattedPrice: String {
        Self.priceFormatter.string(from: viewModel.klineStore.currentPrice as NSDecimalNumber)
            ?? "\(viewModel.klineStore.currentPrice)"
    }

    private var formattedChange: String {
        let change = viewModel.klineStore.priceChange24h
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(Self.changeFormatter.string(from: change as NSDecimalNumber) ?? "\(change)")%"
    }

    private var changeColor: Color {
        viewModel.klineStore.priceChange24h >= 0 ? AppTheme.candleUp : AppTheme.candleDown
    }
}

#Preview {
    ChartContainerView(viewModel: ChartViewModel())
        .frame(width: 1920, height: 1080)
}
