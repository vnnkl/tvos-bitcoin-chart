import SwiftUI

/// Animated banner shown at the top of the chart when a price alert threshold is crossed.
///
/// Slides in from above with a combined move+opacity transition.
/// Auto-dismissed after 3 seconds by the `ChartViewModel` that sets `triggeredAlert = nil`.
///
/// **Layout:** bell icon | "Price Alert" label | price | direction arrow
/// **Background:** `AppTheme.alertBanner` (orange) for maximum visibility against black.
///
/// **Inspectable state:**
/// - Presence on screen means `viewModel.triggeredAlert != nil`
/// - Banner content mirrors `alert.price` and `alert.direction`
struct AlertBannerView: View {

    let alert: PriceAlert

    private static let priceFormatter: NumberFormatter = {
        let f: NumberFormatter = .init()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    var body: some View {
        HStack(spacing: 16) {
            // Bell icon
            Image(systemName: "bell.fill")
                .font(.title2)
                .foregroundStyle(Color.black)

            // "Price Alert" label
            Text("Price Alert")
                .font(.title3.bold())
                .foregroundStyle(Color.black)

            // Divider
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: 1, height: 28)

            // "BTC crossed $XX,XXX.XX"
            Text("BTC crossed \(formattedPrice)")
                .font(.title3)
                .foregroundStyle(Color.black)
                .monospacedDigit()

            // Direction indicator
            Image(systemName: directionSystemImage)
                .font(.title2.bold())
                .foregroundStyle(directionColor)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(AppTheme.alertBanner)
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: - Helpers

    private var formattedPrice: String {
        "$\(Self.priceFormatter.string(from: alert.price as NSDecimalNumber) ?? "\(alert.price)")"
    }

    private var directionSystemImage: String {
        alert.direction == .above ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    private var directionColor: Color {
        alert.direction == .above ? AppTheme.candleUp : AppTheme.candleDown
    }
}
