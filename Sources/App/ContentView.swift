import SwiftUI

/// Root view: `TabView` with Chart tab (live BTC/USDT data) and STRC tab (live strc.live data).
///
/// Both ViewModels are instantiated here as `@State` so they are owned by this view
/// and survive tab switches. `scenePhase` is observed here (not in the App entry
/// point) because `@State` lives at the view hierarchy level.
///
/// Lifecycle contract:
/// - `.active`     → `viewModel.start()` + `strcViewModel.start()` — begins data load
/// - `.background`/`.inactive` → `viewModel.stop()` + `strcViewModel.stop()` — pauses
///   all network activity (tvOS has no background execution budget)
///
/// **Note:** The `Tab {}` constructor requires tvOS 18+. We use the tvOS-17-compatible
/// `.tabItem {}` modifier pattern instead, which uses the same tab bar presentation.
struct ContentView: View {

    @State var viewModel = ChartViewModel(service: BinanceService())
    @State var strcViewModel = STRCViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            // ── Chart tab ──────────────────────────────────────────────
            ChartContainerView(viewModel: viewModel)
                .tabItem {
                    Label("Chart", systemImage: "chart.bar")
                }

            // ── STRC tab ───────────────────────────────────────────────
            STRCDashboardView(viewModel: strcViewModel)
                .tabItem {
                    Label("STRC", systemImage: "building.columns")
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.start()
                strcViewModel.start()
            case .background, .inactive:
                viewModel.stop()
                strcViewModel.stop()
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
