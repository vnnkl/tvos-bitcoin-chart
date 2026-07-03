import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.bitcointerminal.ui", category: "TabMenu")

/// Root view: full-screen tab content with a custom fading tab bar.
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
/// A custom `TabMenuBar` replaces the system `TabView` bar so the content can use
/// the full screen. Visibility contract:
/// - Bar shows on launch with focus on the selected tab.
/// - Moving focus down into the content (or selecting a tab) fades the bar out.
/// - Pressing Menu anywhere in the content fades it back in and focuses it.
/// - Pressing Menu while the bar is focused is unhandled → tvOS exits to the
///   home screen, as the HIG requires.
struct ContentView: View {

    // MARK: - Owned state / stores

    @State var viewModel     = ChartViewModel(service: BinanceService())
    @State var strcViewModel = STRCViewModel()
    @State var appSettings   = AppSettings()
    @State var indicatorSettings = IndicatorSettings()
    @State var alertStore    = AlertStore()
    @State private var defaultsApplied = false

    // MARK: - Tab navigation state

    @State private var selectedTab: AppTab = .chart
    @State private var isMenuVisible = true
    /// True for a short window after a reveal — suppresses the hide-on-focus-loss
    /// rule while the focus engine settles onto the freshly enabled bar.
    @State private var isMenuSettling = false
    @FocusState private var focusedMenuTab: AppTab?

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // ── Main tab navigation ──────────────────────────────────────
            if appSettings.hasSeenDisclaimer {
                // The bar participates in layout (not an overlay) so the focus
                // engine has clean vertical adjacency: bar above, content below.
                // It is conditionally mounted — gating with .disabled() instead
                // leaves the re-enabled buttons unfocusable to the focus engine,
                // so programmatic reveal focus never lands (verified via os_log).
                VStack(spacing: 0) {
                    if isMenuVisible {
                        menuBar
                    }
                    tabContent
                }
            }

            // ── Financial disclaimer — shown once on first launch ────────
            if !appSettings.hasSeenDisclaimer {
                disclaimerOverlay
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: isMenuVisible)
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

    // MARK: - Tab content + menu bar

    /// Full-screen content for the selected tab. Menu press anywhere inside
    /// reveals the tab bar (the bar itself carries no handler, so Menu there
    /// falls through and exits the app).
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .chart:
                ChartContainerView(
                    viewModel: viewModel,
                    indicatorSettings: indicatorSettings,
                    alertStore: alertStore
                )
            case .strc:
                STRCDashboardView(viewModel: strcViewModel)
            case .settings:
                SettingsView(
                    viewModel: viewModel,
                    appSettings: appSettings,
                    alertStore: alertStore,
                    indicatorSettings: indicatorSettings
                )
            }
        }
        .onExitCommand {
            revealMenu()
        }
    }

    private var menuBar: some View {
        TabMenuBar(selectedTab: selectedTab, focusedTab: $focusedMenuTab) { tab in
            selectedTab = tab
            isMenuVisible = false
        }
        .focusSection()
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            focusMenuSoon()
        }
        .onChange(of: focusedMenuTab) { _, newValue in
            // Focus left the bar into the content → fade the bar out so the
            // chart reclaims the full screen. Ignored while the focus engine
            // is still settling onto a freshly revealed bar.
            if newValue == nil && isMenuVisible && !isMenuSettling {
                isMenuVisible = false
            }
        }
    }

    private func revealMenu() {
        logger.info("revealMenu: isMenuVisible=\(self.isMenuVisible)")
        guard !isMenuVisible else { return }
        isMenuVisible = true
        focusMenuSoon()
    }

    /// Move focus onto the selected tab after the bar becomes enabled. A single
    /// attempt can land mid-animation while the bar is still disabled and be
    /// silently dropped by the focus engine, so retry until the binding sticks.
    /// The settle window absorbs transient nil focus values during the process.
    private func focusMenuSoon() {
        isMenuSettling = true
        Task { @MainActor in
            for _ in 0..<8 {
                focusedMenuTab = selectedTab
                try? await Task.sleep(for: .milliseconds(100))
                if focusedMenuTab != nil { break }   // engine accepted the grab
            }
            isMenuSettling = false
            // If focus never landed on the bar, fall back to hiding so the bar
            // can't strand itself visible but unfocused.
            if focusedMenuTab == nil {
                logger.warning("menu bar focus grab failed — hiding bar")
                isMenuVisible = false
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
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.16))
                Image(systemName: "bitcoinsign")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 88, height: 88)
            .padding(.bottom, 8)

            Text("Bitcoin Terminal")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)

            Text("NOT FINANCIAL ADVICE")
                .font(.system(size: 16, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(AppTheme.accent)

            Text(
                "This app displays publicly available market data for informational purposes only. " +
                "It does not constitute financial advice, trading signals, or investment recommendations. " +
                "Always do your own research."
            )
            .font(.title3)
            .foregroundStyle(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 900)

            Button {
                appSettings.hasSeenDisclaimer = true
            } label: {
                Text("I Understand")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 20)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                    .focusHighlight(cornerRadius: AppTheme.cardCornerRadius, scale: 1.05)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .padding(.top, AppTheme.sectionSpacing)
        }
        .padding(AppTheme.edgePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
        .focusSection()
    }
}

#Preview {
    ContentView()
}
