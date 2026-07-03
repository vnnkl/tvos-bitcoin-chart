import SwiftUI

/// BTC accumulation summary card derived from all SEC filings.
///
/// Displays aggregate totals — total estimated BTC purchased, total proceeds,
/// total shares sold, and number of filings — computed from the `[SECFiling]` array.
///
/// Accepts an empty array before data loads (shows zeros gracefully).
struct STRCAccumulationView: View {

    let filings: [SECFiling]

    // MARK: - Derived totals

    private var totalEstimatedBTC: Double {
        filings.reduce(0) { $0 + $1.estimatedBTCPurchased }
    }

    private var totalProceeds: Int {
        filings.reduce(0) { $0 + $1.netProceeds }
    }

    private var totalShares: Int {
        filings.reduce(0) { $0 + $1.sharesSold }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ── Header ────────────────────────────────────────────────
            HStack {
                Text("BTC Accumulation")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(filings.count) filing\(filings.count == 1 ? "" : "s")")
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Divider().overlay(AppTheme.textSecondary.opacity(0.4))

            // ── Metrics ───────────────────────────────────────────────
            HStack(spacing: 48) {
                summaryCell(
                    icon: "bitcoinsign.circle.fill",
                    label: "Est. BTC Purchased",
                    value: AppFormatters.btcHoldings.string(from: NSNumber(value: totalEstimatedBTC)) ?? "0",
                    valueColor: AppTheme.strcAccent
                )
                summaryCell(
                    icon: "dollarsign.circle.fill",
                    label: "Total Proceeds",
                    value: formatProceeds(totalProceeds),
                    valueColor: AppTheme.textPrimary
                )
                summaryCell(
                    icon: "chart.bar.fill",
                    label: "Shares Sold",
                    value: AppFormatters.shares.string(from: NSNumber(value: totalShares)) ?? "0",
                    valueColor: AppTheme.textPrimary
                )
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 200)
        .terminalPanel(padding: 28)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func summaryCell(icon: String, label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(valueColor.opacity(0.8))
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(value)
                    .font(.title2).fontWeight(.semibold)
                    .fontDesign(.monospaced)
                    .foregroundStyle(valueColor)
            }
        }
    }

    // MARK: - Formatting

    private func formatProceeds(_ dollars: Int) -> String {
        let billions = Double(dollars) / 1_000_000_000.0
        if billions >= 1 {
            return String(format: "$%.2fB", billions)
        }
        let millions = Double(dollars) / 1_000_000.0
        return String(format: "$%.1fM", millions)
    }
}
