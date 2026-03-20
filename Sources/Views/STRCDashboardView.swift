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
        .padding(AppTheme.edgePadding)
    }

    // MARK: - Main scroll content

    private var scrollContent: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                // ── Dashboard header ──────────────────────────────────
                dashboardHeader

                // ── ATM Status Card ───────────────────────────────────
                STRCStatusCardView(
                    ticker: viewModel.store.tickerData?.tickers["STRC"],
                    isATMActive: viewModel.isATMActive
                )
                .focusSection()

                // ── Accumulation Summary ──────────────────────────────
                STRCAccumulationView(filings: viewModel.store.filings)
                    .focusSection()

                // ── SEC Filings Table ─────────────────────────────────
                STRCFilingsListView(filings: viewModel.store.filings)
                    .focusSection()
            }
            .padding(.horizontal, AppTheme.edgePadding)
            .padding(.vertical, AppTheme.sectionSpacing)
        }
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("STRC Dashboard")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)
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
