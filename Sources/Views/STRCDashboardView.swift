import SwiftUI

/// Main STRC tab view — composes the status card, accumulation summary, and
/// filings table in a scrollable layout.
///
/// Accepts `STRCViewModel` as a parameter (owned by `ContentView` as `@State`).
/// Shows a loading indicator on first fetch, and an error state when the API
/// is unreachable and no cached data is available.
///
/// **10-foot layout:**
/// - 60 pt edge padding (matches `AppTheme.edgePadding`).
/// - All text ≥ `.title3` for legibility at TV viewing distance.
/// - Each section wrapped in `.focusSection()` to isolate Siri Remote focus.
struct STRCDashboardView: View {

    let viewModel: STRCViewModel

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.store.tickerData == nil {
                loadingView
            } else if viewModel.error != nil && viewModel.store.tickerData == nil {
                errorView
            } else {
                scrollContent
            }
        }
    }

    // MARK: - Loading state

    private var loadingView: some View {
        VStack(spacing: AppTheme.sectionSpacing) {
            ProgressView()
                .scaleEffect(2)
                .tint(AppTheme.strcAccent)
            Text("Loading STRC data…")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Error state

    private var errorView: some View {
        VStack(spacing: AppTheme.sectionSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.strcATMStandby)
            Text("Data temporarily unavailable")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Check your network connection and navigate back to retry.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(5)
    }

    // MARK: - Main scroll content

    private var scrollContent: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                // ── Dashboard header ──────────────────────────────────
                dashboardHeader

                // ── ATM Status Card ───────────────────────────────────
                // focusableCard makes these read-only panels focus targets so
                // the Siri Remote can traverse and scroll this dashboard.
                STRCStatusCardView(
                    ticker: viewModel.store.tickerData?.tickers["STRC"],
                    isATMActive: viewModel.isATMActive
                )
                .focusableCard()

                // ── Accumulation Summary ──────────────────────────────
                STRCAccumulationView(filings: viewModel.store.filings)
                    .focusableCard()

                // ── SEC Filings Table ─────────────────────────────────
                STRCFilingsListView(filings: viewModel.store.filings)
                    .focusableCard()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STRC Dashboard")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("ATM STATUS · BTC ACCUMULATION · SEC FILINGS")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            lastUpdatedLabel
        }
    }

    @ViewBuilder
    private var lastUpdatedLabel: some View {
        if viewModel.isLoading {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("Refreshing…")
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        } else if let updated = viewModel.lastUpdated {
            Text("Updated \(relativeTimeString(from: updated))")
                .font(.title3)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Helpers

    private func relativeTimeString(from date: Date) -> String {
        let elapsed = Int(-date.timeIntervalSinceNow)
        if elapsed < 60 {
            return "just now"
        }
        let minutes = elapsed / 60
        return "\(minutes) min ago"
    }
}
