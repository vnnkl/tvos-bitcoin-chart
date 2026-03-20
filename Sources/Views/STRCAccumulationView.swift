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

    // MARK: - Formatters

    private static let btcFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 4
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    private static let proceedsFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 2
        // Display in billions
        return f
    }()

    private static let sharesFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

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
                    value: Self.btcFormatter.string(from: NSNumber(value: totalEstimatedBTC)) ?? "0",
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
                    value: Self.sharesFormatter.string(from: NSNumber(value: totalShares)) ?? "0",
                    valueColor: AppTheme.textPrimary
                )
            }
        }
        .padding(28)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 200)
        .background(AppTheme.strcCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
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
