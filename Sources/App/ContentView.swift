import SwiftUI

/// Root view that composes the full Bitcoin Terminal UI:
/// - Price ticker at the top
/// - Main chart (candlestick or line) in the centre
/// - Volume histogram below the chart
/// - Connection status indicator at the bottom-right
struct ContentView: View {

    @State private var viewModel = ChartViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // --- Price ticker ---
                PriceTickerView(
                    price: viewModel.klineStore.currentPrice,
                    change24h: viewModel.klineStore.priceChange24h,
                    symbol: "BTC/USDT",
                    interval: viewModel.currentInterval
                )
                .padding(.top, AppTheme.edgePadding)
                .padding(.bottom, AppTheme.sectionSpacing)

                // --- Main chart area ---
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
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)

                // --- Volume bars (25 % of chart height by ratio) ---
                VolumeBarView(klines: viewModel.klineStore.klines)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: UIScreen.main.bounds.height * AppTheme.volumeHeightRatio
                    )
                    .padding(.bottom, AppTheme.sectionSpacing)
            }

            // --- Connection state indicator ---
            ConnectionStatusView(state: viewModel.connectionState)
                .padding(.trailing, AppTheme.edgePadding)
                .padding(.bottom, AppTheme.edgePadding)
        }
        .task {
            viewModel.start()
        }
    }
}

#Preview {
    ContentView()
}
