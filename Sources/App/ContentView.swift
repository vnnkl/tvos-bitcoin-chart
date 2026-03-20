import SwiftUI

/// Root view: `TabView` with Chart tab (live BTC/USDT data) and STRC tab (placeholder).
///
/// `ChartViewModel` is instantiated here as `@State` so it is owned by this view
/// and survives tab switches. `scenePhase` is observed here (not in the App entry
/// point) because `@State` lives at the view hierarchy level — the viewModel is
/// not accessible from `BitcoinTerminalApp`.
///
/// Lifecycle contract:
/// - `.active`     → `viewModel.start()` — begins REST historical load + WebSocket
/// - `.background`/`.inactive` → `viewModel.stop()` — disconnects WebSocket
///   (tvOS has no background execution budget; keeping a connection alive after
///   backgrounding leads to silent stream death and stale state on return)
///
/// **Note:** The `Tab {}` constructor requires tvOS 18+. We use the tvOS-17-compatible
/// `.tabItem {}` modifier pattern instead, which uses the same tab bar presentation.
struct ContentView: View {

    @State var viewModel = ChartViewModel(service: BinanceService())
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            // ── Chart tab ──────────────────────────────────────────────
            ChartContainerView(viewModel: viewModel)
                .tabItem {
                    Label("Chart", systemImage: "chart.bar")
                }

            // ── STRC placeholder tab ───────────────────────────────────
            strc
                .tabItem {
                    Label("STRC", systemImage: "building.columns")
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.start()
            case .background, .inactive:
                viewModel.stop()
            @unknown default:
                break
            }
        }
    }

    // MARK: - STRC placeholder

    @ViewBuilder
    private var strc: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: AppTheme.sectionSpacing) {
                Image(systemName: "building.columns")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("STRC Dashboard")
                    .font(AppTheme.headlineFont)           // .title2
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Coming Soon")
                    .font(AppTheme.bodyFont)               // .title3
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(AppTheme.edgePadding)
        }
    }
}

#Preview {
    ContentView()
}
