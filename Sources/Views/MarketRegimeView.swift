import SwiftUI

struct MarketRegimeStripView: View {

    let regime: MarketRegimeState

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: regime.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(regime.accentColor)

                Text(regime.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Rectangle()
                .fill(AppTheme.separator)
                .frame(width: 1, height: 22)

            Text(regime.summary)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                .fill(AppTheme.surface)
        )
    }
}

struct MarketRegimeBannerView: View {

    let regime: MarketRegimeState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: regime.systemImage)
                .font(.title2)
                .foregroundStyle(.black)

            VStack(alignment: .leading, spacing: 4) {
                Text("Market Regime Shift")
                    .font(.title3.bold())
                    .foregroundStyle(.black)

                Text(regime.title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.black)

                Text(regime.summary)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.72))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(regime.accentColor)
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
    }
}

private extension MarketRegimeState {

    var systemImage: String {
        switch kind {
        case .warmingUp: "waveform.path.ecg"
        case .rangeCompression: "arrow.left.and.right.circle.fill"
        case .balancedFlow: "equal.circle.fill"
        case .aggressiveBuyers: "arrow.up.forward.circle.fill"
        case .aggressiveSellers: "arrow.down.forward.circle.fill"
        case .trendUpBidsHolding: "arrow.up.right.circle.fill"
        case .trendDownOffersHeavy: "arrow.down.right.circle.fill"
        }
    }

    var accentColor: Color {
        switch kind {
        case .warmingUp: AppTheme.indicatorSMA
        case .rangeCompression: AppTheme.indicatorSignal
        case .balancedFlow: AppTheme.textSecondary
        case .aggressiveBuyers, .trendUpBidsHolding: AppTheme.candleUp
        case .aggressiveSellers, .trendDownOffersHeavy: AppTheme.candleDown
        }
    }
}
