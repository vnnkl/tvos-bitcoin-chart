import SwiftUI

/// Root view: `TabView` with Chart tab (live BTC/USDT data), STRC tab (live strc.live data),
/// and Settings tab (exchange selection, default timeframe, price alerts).
///
/// All three ViewModels / stores are instantiated here as `@State` so they are owned by
/// this view and survive tab switches. `scenePhase` is observed here (not in the App entry
/// point) because `@State` lives at the view hierarchy level.
///
/// Lifecycle contract:
/// - `.active`     → `viewModel.start()` + `strcViewModel.start()` — begins data load
/// - `.background`/`.inactive` → `viewModel.stop()` + `strcViewModel.stop()` — pauses
///   all network activity (tvOS has no background execution budget)
///
/// **Settings injection:**
/// `appSettings.defaultInterval` is applied to `viewModel.currentInterval` on first `.active`
/// phase if the persisted default differs from the ViewModel's built-in default.
///
/// **Note:** The `Tab {}` constructor requires tvOS 18+. We use the tvOS-17-compatible
/// `.tabItem {}` modifier pattern instead, which uses the same tab bar presentation.
struct ContentView: View {

    @State var viewModel    = ChartViewModel(service: BinanceService())
    @State var strcViewModel = STRCViewModel()
    @State var appSettings  = AppSettings()
    @State var alertStore   = AlertStore()
    @State private var defaultsApplied = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView {
                // ── Chart tab ──────────────────────────────────────────────
                ChartContainerView(viewModel: viewModel, alertStore: alertStore)
                    .tabItem {
                        Label("Chart", systemImage: "chart.bar")
                    }

                // ── STRC tab ───────────────────────────────────────────────
                STRCDashboardView(viewModel: strcViewModel)
                    .tabItem {
                        Label("STRC", systemImage: "building.columns")
                    }

                // ── Settings tab ───────────────────────────────────────────
                SettingsView(viewModel: viewModel, appSettings: appSettings, alertStore: alertStore)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    // Inject alertStore into viewModel so crossing detection has access to alerts.
                    viewModel.alertStore = alertStore
                    // Apply persisted defaults on first activation only.
                    if !defaultsApplied {
                        defaultsApplied = true
                        if appSettings.defaultInterval != viewModel.currentInterval {
                            viewModel.switchInterval(appSettings.defaultInterval)
                        }
                    }
                    viewModel.start()
                    strcViewModel.start()
                case .background, .inactive:
                    viewModel.stop()
                    strcViewModel.stop()
                @unknown default:
                    break
                }
            }

            // Financial disclaimer — shown once on first launch, blocks tab interaction.
            if !appSettings.hasSeenDisclaimer {
                disclaimerOverlay
            }
        }
        .animation(.easeInOut, value: appSettings.hasSeenDisclaimer)
    }

    // MARK: - Financial disclaimer overlay

    /// Full-screen one-time disclaimer overlay. Shown on first launch only; dismissed
    /// by tapping "I Understand", which persists `hasSeenDisclaimer = true`.
    ///
    /// Uses `.focusSection()` so the Siri Remote cannot reach the tabs behind it while
    /// the overlay is visible.
    private var disclaimerOverlay: some View {
        VStack(spacing: AppTheme.sectionSpacing) {
            Text("⚠️ Not Financial Advice")
                .font(.title)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(
                "This app displays publicly available market data for informational purposes only. " +
                "It does not constitute financial advice, trading signals, or investment recommendations. " +
                "Always do your own research."
            )
            .font(.title3)
            .foregroundStyle(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 900)

            Button("I Understand") {
                appSettings.hasSeenDisclaimer = true
            }
            .buttonStyle(.plain)
            .font(.title3)
            .padding(.horizontal, 60)
            .padding(.vertical, 20)
            .background(AppTheme.candleUp)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, AppTheme.sectionSpacing)
        }
        .padding(AppTheme.edgePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
        .focusSection()
    }
}

#Preview {
    ContentView()
}
