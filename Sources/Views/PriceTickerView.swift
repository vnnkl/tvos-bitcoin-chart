import SwiftUI

/// Displays the current BTC/USDT price prominently and the 24 h change percentage.
///
/// tvOS guidelines: price uses `.system(size: 48, weight: .bold)`, secondary labels
/// use `.title3` minimum. The 24 h change is green for positive, red for negative.
struct PriceTickerView: View {

    let price: Decimal
    let change24h: Decimal
    var symbol: String = "BTC/USDT"
    var interval: String = "1m"

    private static let priceFormatter: NumberFormatter = {
        let formatter: NumberFormatter = .init()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private static let changeFormatter: NumberFormatter = {
        let formatter: NumberFormatter = .init()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            // Symbol + interval badge
            VStack(alignment: .leading, spacing: 4) {
                Text(symbol)
                    .font(AppTheme.headlineFont)          // .title2 — legible at 10 ft
                    .foregroundStyle(AppTheme.textPrimary)
                Text(interval)
                    .font(AppTheme.bodyFont)              // .title3 — minimum body size
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            // Price
            Text(formattedPrice)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()

            // 24 h change
            Text(formattedChange)
                .font(AppTheme.priceFont)                // .title
                .foregroundStyle(changeColor)
                .monospacedDigit()
        }
        .padding(.horizontal, AppTheme.edgePadding)
    }

    // MARK: - Private

    private var formattedPrice: String {
        Self.priceFormatter.string(from: price as NSDecimalNumber) ?? "\(price)"
    }

    private var formattedChange: String {
        let sign = change24h >= 0 ? "+" : ""
        return "\(sign)\(Self.changeFormatter.string(from: change24h as NSDecimalNumber) ?? "\(change24h)")%"
    }

    private var changeColor: Color {
        change24h >= 0 ? AppTheme.candleUp : AppTheme.candleDown
    }
}

#Preview {
    PriceTickerView(price: 67_432.10, change24h: 2.34)
        .background(AppTheme.background)
}
