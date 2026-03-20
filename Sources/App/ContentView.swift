import SwiftUI

/// Root view: custom tab switcher with a floating auto-hiding tab bar overlay.
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
/// **Tab navigation (custom tab switcher):**
/// `selectedTab` drives which content view is rendered. The floating pill tab bar
/// overlay is visible on launch for 4 seconds, then auto-hides. A persistent
/// "▲ Menu" hint remains visible at the top when the tab bar is collapsed so
/// the user always knows how to navigate. Swiping up reveals the full tab bar
/// again; it auto-hides ~3 seconds after focus leaves it. The tab bar re-flashes
/// on every tab switch.
struct ContentView: View {

    // MARK: - Owned state / stores

    @State var viewModel     = ChartViewModel(service: BinanceService())
    @State var strcViewModel = STRCViewModel()
    @State var appSettings   = AppSettings()
    @State var alertStore    = AlertStore()
    @State private var defaultsApplied = false

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Tab switcher state

    private enum Tab: String, CaseIterable {
        case chart, strc, settings
    }

    @State private var selectedTab: Tab = .chart
    @State private var tabBarVisible    = true   // visible on launch so user discovers it
    @FocusState private var focusedTab: Tab?
    @State private var hideTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Tab content ──────────────────────────────────────────────
            Group {
                switch selectedTab {
                case .chart:
                    ChartContainerView(viewModel: viewModel, alertStore: alertStore)
                case .strc:
                    STRCDashboardView(viewModel: strcViewModel)
                case .settings:
                    SettingsView(viewModel: viewModel, appSettings: appSettings, alertStore: alertStore)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
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
                    viewModel.stop()
                    strcViewModel.stop()
                @unknown default:
                    break
                }
            }

            // ── Floating tab bar overlay ─────────────────────────────────
            // Present only after the disclaimer is dismissed. The disclaimer's
            // `.focusSection()` absorbs all Siri Remote input during onboarding.
            // Visibility is opacity-controlled (not conditional) so the Focus
            // Engine can always route swipe-up navigation to these buttons.
            if appSettings.hasSeenDisclaimer {
                tabBarOverlay
            }

            // ── Financial disclaimer — shown once on first launch ────────
            if !appSettings.hasSeenDisclaimer {
                disclaimerOverlay
            }
        }
        .animation(.easeInOut, value: appSettings.hasSeenDisclaimer)
        .onChange(of: focusedTab) { _, newTab in
            if newTab != nil {
                // Focus entered the tab bar — make it visible and cancel any pending hide.
                tabBarVisible = true
                hideTask?.cancel()
                hideTask = nil
            } else {
                // Focus left the tab bar — schedule auto-hide after 3 seconds.
                scheduleTabBarHide()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            // Re-flash the tab bar on every tab switch so user sees current position.
            tabBarVisible = true
            scheduleTabBarHide()
        }
        .task {
            // Auto-hide after initial 4-second reveal on launch.
            try? await Task.sleep(for: .seconds(4))
            if focusedTab == nil { tabBarVisible = false }
        }
    }

    // MARK: - Tab Bar Helpers

    /// Cancel any pending hide and schedule a new 3-second auto-hide.
    private func scheduleTabBarHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { tabBarVisible = false }
        }
    }

    // MARK: - Floating Tab Bar Overlay

    /// Pill-style tab switcher anchored at the top of the screen.
    ///
    /// Opacity drives show/hide (not conditional rendering) so focusable buttons
    /// remain in the view hierarchy at all times. The overlay auto-hides ~3 s after
    /// focus leaves the section. When collapsed, a persistent "▲ Menu" hint capsule
    /// stays visible so the user always knows navigation is available via swipe-up.
    private var tabBarOverlay: some View {
        VStack(spacing: 0) {
            // ── Full tab bar (opacity-controlled) ────────────────────
            HStack(spacing: 12) {
                // ── Chart button ────────────────────────────────────────
                Button {
                    selectedTab = .chart
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar")
                        Text("Chart")
                    }
                    .font(.system(size: 24, weight: selectedTab == .chart ? .bold : .medium))
                    .foregroundStyle(selectedTab == .chart ? Color.black : AppTheme.textPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(selectedTab == .chart ? AppTheme.candleUp : Color(white: 0.12))
                    )
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .focused($focusedTab, equals: .chart)
                .scaleEffect(focusedTab == .chart ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: focusedTab == .chart)

                // ── STRC button ─────────────────────────────────────────
                Button {
                    selectedTab = .strc
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "building.columns")
                        Text("STRC")
                    }
                    .font(.system(size: 24, weight: selectedTab == .strc ? .bold : .medium))
                    .foregroundStyle(selectedTab == .strc ? Color.black : AppTheme.textPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(selectedTab == .strc ? AppTheme.candleUp : Color(white: 0.12))
                    )
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .focused($focusedTab, equals: .strc)
                .scaleEffect(focusedTab == .strc ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: focusedTab == .strc)

                // ── Settings button ─────────────────────────────────────
                Button {
                    selectedTab = .settings
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(.system(size: 24, weight: selectedTab == .settings ? .bold : .medium))
                    .foregroundStyle(selectedTab == .settings ? Color.black : AppTheme.textPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(selectedTab == .settings ? AppTheme.candleUp : Color(white: 0.12))
                    )
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .focused($focusedTab, equals: .settings)
                .scaleEffect(focusedTab == .settings ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: focusedTab == .settings)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(white: 0.08).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .focusSection()
            .onExitCommand { tabBarVisible = false }
            .opacity(tabBarVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: tabBarVisible)

            // ── Persistent "▲ Menu" hint — visible when tab bar is collapsed ──
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Menu")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(white: 0.08).opacity(0.7))
            .clipShape(Capsule())
            .opacity(tabBarVisible ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: tabBarVisible)
            .padding(.top, 4)
            .allowsHitTesting(false)

            Spacer()
        }
        .padding(.top, AppTheme.edgePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
