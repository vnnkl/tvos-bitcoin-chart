import SwiftUI

/// Root view: native tvOS TabView with three tabs.
///
/// The three view models / stores are owned here as `@State` so they survive tab
/// switches. `scenePhase` is observed here (not in the App entry point) because
/// `@State` lives at the view hierarchy level.
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
/// **Tab navigation:**
/// Uses native tvOS `TabView` with `.tabItem` for system-standard focus routing,
/// Menu button handling, and tab bar visibility. The tab bar auto-shows when the
/// user swipes up. No custom overlay needed.
struct ContentView: View {

    // MARK: - Owned state / stores

    @State var viewModel     = ChartViewModel(service: BinanceService())
    @State var strcViewModel = STRCViewModel()
    @State var appSettings   = AppSettings()
    @State var alertStore    = AlertStore()
    @State private var defaultsApplied = false

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Main tab navigation ──────────────────────────────────────
            if appSettings.hasSeenDisclaimer {
                TabView {
                    ChartContainerView(viewModel: viewModel, alertStore: alertStore)
                        .tabItem { Label("Chart", systemImage: "chart.bar") }

                    STRCDashboardView(viewModel: strcViewModel)
                        .tabItem { Label("STRC", systemImage: "building.columns") }

                    SettingsView(viewModel: viewModel, appSettings: appSettings, alertStore: alertStore)
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            }

            // ── Financial disclaimer — shown once on first launch ────────
            if !appSettings.hasSeenDisclaimer {
                disclaimerOverlay
            }
        }
        .animation(.easeInOut, value: appSettings.hasSeenDisclaimer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Prevent tvOS screensaver — this app is designed to stay on.
                UIApplication.shared.isIdleTimerDisabled = true
                // Inject alertStore into viewModel so alert crossing detection works.
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
                UIApplication.shared.isIdleTimerDisabled = false
                viewModel.stop()
                strcViewModel.stop()
            @unknown default:
                break
            }
        }
    }

    // MARK: - Financial Disclaimer Overlay

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
            .focusEffectDisabled()
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
