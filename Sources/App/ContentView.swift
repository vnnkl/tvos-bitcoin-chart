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
/// `selectedTab` drives which content view is rendered. Swipe up to reveal the floating
/// pill tab bar overlay; it auto-hides after ~3 seconds once focus leaves it. The tab bar
/// is always present in the view hierarchy after the disclaimer is dismissed (opacity-
/// controlled, not conditionally rendered) so the tvOS Focus Engine can navigate to it
/// via upward swipe at any time.
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
    @State private var tabBarVisible    = false
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
                hideTask?.cancel()
                hideTask = Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run { tabBarVisible = false }
                }
            }
        }
    }

    // MARK: - Floating Tab Bar Overlay

    /// Pill-style tab switcher anchored at the top of the screen.
    ///
    /// Opacity drives show/hide (not conditional rendering) so focusable buttons
    /// remain in the view hierarchy at all times. The overlay auto-hides ~3 s after
    /// focus leaves the section. Inspectable via `tabBarVisible` in the SwiftUI
    /// debug inspector; inspect `hideTask` to confirm timer is running.
    private var tabBarOverlay: some View {
        VStack(spacing: 0) {
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
