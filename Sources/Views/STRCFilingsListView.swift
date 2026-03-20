import SwiftUI

/// SEC 8-K ATM filings table — shows the most recent filings with all key columns.
///
/// Displays up to 10 most recent filings. If the total exceeds 10, a note is shown
/// at the bottom indicating how many additional filings exist.
///
/// Text is `.title3` minimum with `.monospacedDigit()` for numeric columns.
struct STRCFilingsListView: View {

    let filings: [SECFiling]

    private let maxDisplayed = 10

    private var displayedFilings: [SECFiling] {
        Array(filings.prefix(maxDisplayed))
    }

    private var remainingCount: Int {
        max(0, filings.count - maxDisplayed)
    }

    // MARK: - Formatters

    private static let sharesFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    private static let btcFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 3
        f.usesGroupingSeparator = true
        return f
    }()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ────────────────────────────────────────────────
            HStack {
                Text("SEC Filings")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(filings.count) total")
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 16)

            Divider().overlay(AppTheme.textSecondary.opacity(0.4))

            // ── Column headers ────────────────────────────────────────
            columnHeaders
                .padding(.horizontal, 28)
                .padding(.vertical, 12)

            Divider().overlay(AppTheme.textSecondary.opacity(0.3))

            // ── Rows ──────────────────────────────────────────────────
            if filings.isEmpty {
                Text("No filings yet")
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(28)
            } else {
                ForEach(Array(displayedFilings.enumerated()), id: \.element.filedDate) { idx, filing in
                    filingRow(filing: filing, isAlternate: idx % 2 == 1)
                }

                if remainingCount > 0 {
                    Divider().overlay(AppTheme.textSecondary.opacity(0.3))
                    Text("… and \(remainingCount) more filing\(remainingCount == 1 ? "" : "s") — see strc.live for full history")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
            }
        }
        .background(AppTheme.strcCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    // MARK: - Column headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("Filed Date")
                .frame(width: 160, alignment: .leading)
            Text("Period")
                .frame(width: 220, alignment: .leading)
            Text("Shares")
                .frame(minWidth: 160, alignment: .trailing)
            Text("Proceeds")
                .frame(minWidth: 180, alignment: .trailing)
            Text("Est. BTC")
                .frame(minWidth: 160, alignment: .trailing)
            Text("Type")
                .frame(minWidth: 120, alignment: .trailing)
        }
        .font(.title3)
        .foregroundStyle(AppTheme.textSecondary)
    }

    // MARK: - Row

    @ViewBuilder
    private func filingRow(filing: SECFiling, isAlternate: Bool) -> some View {
        HStack(spacing: 0) {
            Text(filing.filedDate)
                .frame(width: 160, alignment: .leading)
                .foregroundStyle(AppTheme.textSecondary)

            Text(filing.period ?? "—")
                .frame(width: 220, alignment: .leading)
                .foregroundStyle(AppTheme.textSecondary)

            Text(Self.sharesFormatter.string(from: NSNumber(value: filing.sharesSold)) ?? "—")
                .frame(minWidth: 160, alignment: .trailing)
                .foregroundStyle(AppTheme.textPrimary)

            Text(formatProceeds(filing.netProceeds))
                .frame(minWidth: 180, alignment: .trailing)
                .foregroundStyle(AppTheme.textPrimary)

            Text(Self.btcFormatter.string(from: NSNumber(value: filing.estimatedBTCPurchased)) ?? "—")
                .frame(minWidth: 160, alignment: .trailing)
                .foregroundStyle(AppTheme.strcAccent)

            offeringTypeBadge(filing.offeringType)
                .frame(minWidth: 120, alignment: .trailing)
        }
        .font(.title3)
        .fontDesign(.monospaced)
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(isAlternate ? AppTheme.textSecondary.opacity(0.04) : Color.clear)
    }

    // MARK: - Offering type badge

    @ViewBuilder
    private func offeringTypeBadge(_ type: String) -> some View {
        let (label, color) = badgeStyle(for: type)
        Text(label)
            .font(.title3)
            .fontDesign(.default)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius))
    }

    private func badgeStyle(for type: String) -> (String, Color) {
        switch type.lowercased() {
        case "atm":        return ("ATM",        AppTheme.strcAccent)
        case "ipo":        return ("IPO",        AppTheme.candleUp)
        case "follow_on":  return ("Follow-On",  AppTheme.strcATMStandby)
        default:           return (type.uppercased(), AppTheme.textSecondary)
        }
    }

    // MARK: - Formatting

    private func formatProceeds(_ dollars: Int) -> String {
        let millions = Double(dollars) / 1_000_000.0
        return String(format: "$%.1fM", millions)
    }
}
