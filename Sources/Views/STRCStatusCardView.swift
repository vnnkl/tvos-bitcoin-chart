import SwiftUI

/// ATM status card showing current STRC price, ATM status, yield, vs-par distance,
/// and next ex-dividend date.
///
/// Accepts `STRCTicker?` — renders a placeholder skeleton when data is `nil`.
///
/// Text sizes are `.title3` minimum throughout for 10-foot legibility.
struct STRCStatusCardView: View {

    let ticker: STRCTicker?
    let isATMActive: Bool

    // MARK: - Formatters

    private static let currencyFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static let percentFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .percent
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 2
        f.multiplier = 1   // values are already in percent form (e.g. 11.5 not 0.115)
        return f
    }()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ── Header row ────────────────────────────────────────────
            HStack(alignment: .center, spacing: 16) {
                Text("STRC")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)

                atmBadge

                Spacer()

                if let ticker {
                    priceDisplay(ticker: ticker)
                }
            }

            Divider().overlay(AppTheme.textSecondary.opacity(0.4))

            // ── Metrics grid ──────────────────────────────────────────
            if let ticker {
                HStack(spacing: 40) {
                    metricCell(
                        label: "Yield",
                        value: ticker.summary.currentYield.map { formatPercent($0) } ?? "—",
                        valueColor: AppTheme.strcAccent
                    )
                    metricCell(
                        label: "Vs Par",
                        value: formatVsPar(ticker.closePrice),
                        valueColor: ticker.closePrice >= 100 ? AppTheme.candleUp : AppTheme.candleDown
                    )
                    if let div = ticker.dividends.current {
                        metricCell(
                            label: "Next Ex-Div",
                            value: div.exDate,
                            valueColor: AppTheme.textPrimary
                        )
                        metricCell(
                            label: "Dividend",
                            value: Self.currencyFormatter.string(from: NSNumber(value: div.amount)) ?? "—",
                            valueColor: AppTheme.textPrimary
                        )
                        metricCell(
                            label: "Pay Date",
                            value: div.payDate,
                            valueColor: AppTheme.textSecondary
                        )
                    }
                }
            } else {
                placeholderMetrics
            }

            // ── Extended hours ────────────────────────────────────────
            if let ticker,
               let ahPrice = ticker.extendedHoursPrice,
               let ahChange = ticker.extendedHoursChangePercent {
                Divider().overlay(AppTheme.textSecondary.opacity(0.4))
                HStack(spacing: 12) {
                    Text("After Hours")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(Self.currencyFormatter.string(from: NSNumber(value: ahPrice)) ?? "—")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textPrimary)
                    changeLabel(ahChange)
                    Text("AH")
                        .font(.caption)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppTheme.textSecondary.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(28)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 200)
        .background(AppTheme.strcCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var atmBadge: some View {
        let badgeColor = isATMActive ? AppTheme.strcATMActive : AppTheme.strcATMStandby
        Text(isATMActive ? "Active" : "Standby")
            .font(.title3).fontWeight(.semibold)
            .foregroundStyle(Color.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(badgeColor)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func priceDisplay(ticker: STRCTicker) -> some View {
        let change = ticker.closePrice - ticker.previousClose
        let changePct = ticker.previousClose > 0 ? change / ticker.previousClose * 100 : 0
        VStack(alignment: .trailing, spacing: 4) {
            Text(Self.currencyFormatter.string(from: NSNumber(value: ticker.closePrice)) ?? "—")
                .font(.title)
                .fontDesign(.monospaced)
                .foregroundStyle(AppTheme.textPrimary)
            changeLabel(changePct)
        }
    }

    @ViewBuilder
    private func changeLabel(_ pct: Double) -> some View {
        let color = pct >= 0 ? AppTheme.candleUp : AppTheme.candleDown
        let sign  = pct >= 0 ? "+" : ""
        Text("\(sign)\(String(format: "%.2f", pct))%")
            .font(.title3)
            .fontDesign(.monospaced)
            .foregroundStyle(color)
    }

    @ViewBuilder
    private func metricCell(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.title3)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title3).fontWeight(.semibold)
                .fontDesign(.monospaced)
                .foregroundStyle(valueColor)
        }
    }

    @ViewBuilder
    private var placeholderMetrics: some View {
        HStack(spacing: 40) {
            ForEach(["Yield", "Vs Par", "Next Ex-Div"], id: \.self) { label in
                metricCell(label: label, value: "—", valueColor: AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Formatting helpers

    private func formatPercent(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value)) ?? "—"
    }

    private func formatVsPar(_ close: Double) -> String {
        let delta = close - 100.0
        let sign  = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", delta))"
    }
}
