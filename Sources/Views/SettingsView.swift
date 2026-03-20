import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.bitcointerminal.websocket", category: "SettingsView")

/// tvOS settings screen accessible via the third tab in the custom tab switcher.
///
/// Three focus-isolated sections per tvOS Focus Engine best practices:
/// 1. **Exchange** — switches live data source between Binance and Stub (R009).
/// 2. **Default Timeframe** — persists the interval applied on next app launch.
/// 3. **Price Alerts** — CRUD interface for threshold-crossing alerts (R012).
///
/// Each section is wrapped in `.focusSection()` to prevent unexpected Siri Remote
/// focus jumps between groups.
///
/// **Observability:**
/// - `viewModel.service` type name indicates active exchange after a swap.
/// - `appSettings.selectedExchange` persists selection across launches.
/// - `alertStore.alerts.count` reflects add/remove actions immediately.
@MainActor
struct SettingsView: View {

    // MARK: - Dependencies

    @Bindable var viewModel: ChartViewModel
    var appSettings: AppSettings
    var alertStore: AlertStore

    // MARK: - Local state

    /// Exchange picker selection drives both `appSettings` and `viewModel.switchExchange()`.
    @State private var selectedExchange: String = "binance"

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                // ── Page heading ──────────────────────────────────────────
                Text("Settings")
                    .font(AppTheme.dataHeaderFont)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.bottom, 8)

                // ── Section 1: Exchange ───────────────────────────────────
                exchangeSection
                    .focusSection()

                // ── Section 2: Default Timeframe ──────────────────────────
                timeframeSection
                    .focusSection()

                // ── Section 3: Price Alerts ───────────────────────────────
                alertsSection
                    .focusSection()
            }
            .padding(5)
        }
        .background(AppTheme.background)
        .onAppear {
            // Sync local picker state from persisted settings.
            selectedExchange = appSettings.selectedExchange
        }
    }

    // MARK: - Exchange Section

    private var exchangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Exchange", icon: "network")

            VStack(spacing: 12) {
                exchangeButton(id: "binance", label: "Binance", subtitle: "Live data via WebSocket")
                exchangeButton(id: "stub",    label: "Stub (Demo)", subtitle: "Fixture data — no network required")
            }
            .padding(20)
            .background(AppTheme.strcCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        }
    }

    @ViewBuilder
    private func exchangeButton(id: String, label: String, subtitle: String) -> some View {
        let isSelected = selectedExchange == id

        Button {
            guard selectedExchange != id else { return }
            logger.info("SettingsView: switching exchange to \(id)")
            selectedExchange = id
            appSettings.selectedExchange = id

            let newService: any ExchangeDataService = (id == "stub")
                ? StubExchangeService()
                : BinanceService()
            viewModel.switchExchange(newService)
        } label: {
            HStack(spacing: 16) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.candleUp : AppTheme.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fontWeight(isSelected ? .semibold : .regular)

                    Text(subtitle)
                        .font(AppTheme.dataFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                    .fill(isSelected ? AppTheme.candleUp.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    // MARK: - Timeframe Section

    private var timeframeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Default Timeframe", icon: "clock")

            Text("Applied on next app launch — does not change the live chart.")
                .font(AppTheme.dataFont)
                .foregroundStyle(AppTheme.textSecondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 10)],
                spacing: 10
            ) {
                ForEach(TimeframeSelectorView.intervals, id: \.self) { interval in
                    intervalButton(interval)
                }
            }
            .padding(20)
            .background(AppTheme.strcCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        }
    }

    @ViewBuilder
    private func intervalButton(_ interval: String) -> some View {
        let isDefault = appSettings.defaultInterval == interval

        Button {
            appSettings.defaultInterval = interval
            logger.info("SettingsView: default interval set to \(interval)")
        } label: {
            Text(interval)
                .font(AppTheme.bodyFont)
                .monospacedDigit()
                .fontWeight(isDefault ? .semibold : .regular)
                .foregroundStyle(isDefault ? .black : AppTheme.textPrimary)
                .frame(minWidth: 80, minHeight: 60)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                        .fill(isDefault ? AppTheme.candleUp : Color(white: 0.25))
                )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionHeader("Price Alerts", icon: "bell.badge")
                Spacer()
                addAlertButtons
            }

            if alertStore.alerts.isEmpty {
                Text("No alerts configured. Add one below to be notified when BTC crosses a price level.")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.strcCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            } else {
                VStack(spacing: 8) {
                    ForEach(alertStore.alerts) { alert in
                        alertRow(alert)
                    }
                }
                .padding(12)
                .background(AppTheme.strcCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            }
        }
    }

    /// "Add Above" and "Add Below" buttons placed near the section header.
    private var addAlertButtons: some View {
        HStack(spacing: 12) {
            addAlertButton(direction: .above, label: "+ Above")
            addAlertButton(direction: .below, label: "+ Below")
        }
    }

    @ViewBuilder
    private func addAlertButton(direction: AlertDirection, label: String) -> some View {
        Button {
            addAlert(direction: direction)
        } label: {
            Text(label)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                        .fill(direction == .above ? AppTheme.candleUp.opacity(0.25)
                                                  : AppTheme.candleDown.opacity(0.25))
                )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    @ViewBuilder
    private func alertRow(_ alert: PriceAlert) -> some View {
        HStack(spacing: 16) {
            // Direction badge
            directionBadge(alert.direction)

            // Price + status
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(alert.price.formatted())")
                    .font(AppTheme.bodyFont)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 8) {
                    if alert.hasTriggered {
                        Label("Fired", systemImage: "bell.fill")
                            .font(AppTheme.dataFont)
                            .foregroundStyle(AppTheme.alertBanner)
                    } else if alert.isEnabled {
                        Label("Armed", systemImage: "bell")
                            .font(AppTheme.dataFont)
                            .foregroundStyle(AppTheme.stateConnected)
                    } else {
                        Label("Disabled", systemImage: "bell.slash")
                            .font(AppTheme.dataFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // Re-arm button (only shown if triggered)
            if alert.hasTriggered {
                Button {
                    alertStore.resetAlert(id: alert.id)
                } label: {
                    Text("Re-arm")
                        .font(AppTheme.dataFont)
                        .foregroundStyle(AppTheme.strcAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.strcAccent.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }

            // Delete button
            Button(role: .destructive) {
                alertStore.remove(id: alert.id)
                logger.info("SettingsView: removed alert id=\(alert.id)")
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(AppTheme.candleDown)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.candleDown.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.15))
        )
    }

    @ViewBuilder
    private func directionBadge(_ direction: AlertDirection) -> some View {
        let (icon, color) = direction == .above
            ? ("arrow.up.circle.fill", AppTheme.candleUp)
            : ("arrow.down.circle.fill", AppTheme.candleDown)

        Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(color)
            .frame(width: 36)
    }

    // MARK: - Helpers

    /// Adds a new alert ±1% from the most recent chart close price.
    private func addAlert(direction: AlertDirection) {
        // Use the last close kline price as the reference; fall back to a round BTC estimate.
        let lastClose = viewModel.klineStore.klines.last?.close ?? Decimal(42000)
        let factor: Decimal = direction == .above
            ? Decimal(string: "1.01")!
            : Decimal(string: "0.99")!
        let threshold = (lastClose * factor).rounded(scale: 2)
        alertStore.add(price: threshold, direction: direction)
        logger.info("SettingsView: added \(direction.rawValue) alert at \(threshold)")
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTheme.dataHeaderFont)
            .foregroundStyle(AppTheme.textPrimary)
    }
}

// MARK: - Decimal rounding helper

private extension Decimal {
    /// Round to `scale` decimal places using banking (half-even) rounding.
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var mutable = self
        NSDecimalRound(&result, &mutable, scale, .bankers)
        return result
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var settings = AppSettings()
    @Previewable @State var alerts   = AlertStore()
    @Previewable @State var vm       = ChartViewModel(service: StubExchangeService())

    SettingsView(viewModel: vm, appSettings: settings, alertStore: alerts)
        .frame(width: 1920, height: 1080)
        .background(AppTheme.background)
}
