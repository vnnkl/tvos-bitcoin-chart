import SwiftUI

/// Composes the full chart UI into a single container:
/// price header (symbol, price, 24h change), chart mode toggle, connection status,
/// candlestick/line chart, and volume histogram.
///
/// Uses `@Bindable` so the segmented `Picker` can write back to
/// `viewModel.chartMode` directly via `$viewModel.chartMode`.
///
/// **Layout:** Header occupies natural height; chart fills the remaining vertical
/// space; volume bars get `AppTheme.volumeHeightRatio` (20%) of the container height
/// via `GeometryReader`. Edge padding of `AppTheme.edgePadding` (60 pt) is applied
/// to the whole container, satisfying tvOS safe-area guidelines.
struct ChartContainerView: View {

    @Bindable var viewModel: ChartViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // ── Header row ─────────────────────────────────────────
                HStack(alignment: .center, spacing: AppTheme.sectionSpacing) {
                    priceSection
                    Spacer()
                    chartModeToggle
                    Spacer()
                    ConnectionStatusView(state: viewModel.connectionState)
                }
                .padding(.bottom, AppTheme.sectionSpacing)

                // ── Main chart (fills remaining height) ───────────────
                chartArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── Volume histogram (20 % of container height) ───────
                VolumeBarView(klines: viewModel.klineStore.klines)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: geometry.size.height * AppTheme.volumeHeightRatio
                    )
                    .padding(.top, 12)
            }
            .padding(AppTheme.edgePadding)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    // MARK: - Header: price section

    @ViewBuilder
    private var priceSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            // Symbol + interval badge
            VStack(alignment: .leading, spacing: 4) {
                Text("BTC/USDT")
                    .font(AppTheme.headlineFont)           // .title2
                    .foregroundStyle(AppTheme.textPrimary)
                Text(viewModel.currentInterval)
                    .font(AppTheme.bodyFont)               // .title3 minimum
                    .foregroundStyle(AppTheme.textSecondary)
            }

            // Live price
            Text(formattedPrice)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())

            // 24 h change
            Text(formattedChange)
                .font(AppTheme.priceFont)                  // .title
                .foregroundStyle(changeColor)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    // MARK: - Header: chart mode toggle (Siri Remote focusable)

    @ViewBuilder
    private var chartModeToggle: some View {
        Picker("Chart Mode", selection: $viewModel.chartMode) {
            Text("Candlestick").tag(ChartMode.candlestick)
            Text("Line").tag(ChartMode.line)
        }
        .pickerStyle(.segmented)
        .frame(width: 360)
    }

    // MARK: - Chart area

    @ViewBuilder
    private var chartArea: some View {
        ZStack {
            switch viewModel.chartMode {
            case .candlestick:
                CandlestickChartView(klines: viewModel.klineStore.klines)
            case .line:
                LineChartView(klines: viewModel.klineStore.klines)
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
