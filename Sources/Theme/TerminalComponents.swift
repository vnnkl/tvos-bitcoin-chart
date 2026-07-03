import SwiftUI

// MARK: - Panel chrome

/// Shared panel-card chrome: near-black fill, hairline stroke, rounded corners.
///
/// Used for every data zone (chart, order book, trades, settings cards) so the
/// whole app reads as one system of floating panels on the OLED-black canvas.
private struct TerminalPanelModifier: ViewModifier {

    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                    .fill(AppTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                    .strokeBorder(AppTheme.panelStroke, lineWidth: 1)
            )
    }
}

extension View {
    /// Wraps the view in the shared terminal panel card.
    func terminalPanel(padding: CGFloat = 16) -> some View {
        modifier(TerminalPanelModifier(padding: padding))
    }
}

// MARK: - Micro-label

/// Uppercase tracked micro-label used as a panel section header
/// ("ORDER BOOK", "TRADES", "SEC FILINGS").
struct PanelHeaderLabel: View {

    let text: String
    var icon: String? = nil
    var tint: Color = AppTheme.textMuted

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
            }
            Text(text.uppercased())
                .font(AppTheme.microLabelFont)
                .tracking(AppTheme.microLabelTracking)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Focus highlight

/// Focus-aware visuals for Button labels: accent ring, gentle scale, and an
/// accent glow when the enclosing focusable element has Siri Remote focus.
///
/// Apply to the **label content** of a `Button` styled `.plain` with
/// `.focusEffectDisabled()` — the label sits inside the focusable button, so
/// `@Environment(\.isFocused)` reflects the button's focus state.
private struct FocusHighlightModifier: ViewModifier {

    @Environment(\.isFocused) private var isFocused

    var cornerRadius: CGFloat
    var scale: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(AppTheme.accent, lineWidth: isFocused ? 3 : 0)
            )
            .shadow(
                color: AppTheme.accent.opacity(isFocused ? 0.35 : 0),
                radius: isFocused ? 14 : 0
            )
            .scaleEffect(isFocused ? scale : 1.0)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

extension View {
    /// Focus ring + scale + glow for custom tvOS button labels.
    func focusHighlight(cornerRadius: CGFloat = AppTheme.badgeCornerRadius,
                        scale: CGFloat = 1.08) -> some View {
        modifier(FocusHighlightModifier(cornerRadius: cornerRadius, scale: scale))
    }
}

// MARK: - Focusable card

/// Makes a non-interactive panel focusable so the Siri Remote can traverse and
/// scroll read-only screens (e.g. the STRC dashboard). Focus is shown with a
/// subtle accent ring and lift — never an invisible focus target.
private struct FocusableCardModifier: ViewModifier {

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                    .strokeBorder(AppTheme.accent.opacity(isFocused ? 0.7 : 0), lineWidth: 2)
            )
            .scaleEffect(isFocused ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

extension View {
    /// Focusable wrapper for read-only panel cards, with visible focus.
    func focusableCard() -> some View {
        modifier(FocusableCardModifier())
    }
}

// MARK: - Pill label

/// Compact pill used for timeframe buttons, chart-mode toggles, and similar
/// header controls. Active state fills with the Bitcoin-orange accent.
struct PillLabel: View {

    let text: String
    var isActive: Bool = false
    var minWidth: CGFloat = 64

    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: isActive ? .bold : .medium, design: .monospaced))
            .foregroundStyle(isActive ? .black : AppTheme.textPrimary)
            .frame(minWidth: minWidth, minHeight: 52)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                    .fill(isActive ? AppTheme.accent : Color(white: 0.12))
            )
            .focusHighlight()
    }
}

/// Square icon pill for header controls (zoom in/out).
struct IconPillLabel: View {

    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(minWidth: 52, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.badgeCornerRadius)
                    .fill(Color(white: 0.12))
            )
            .focusHighlight()
    }
}

// MARK: - Header stat block

/// Small labeled statistic for the header strip (24H HIGH / LOW / VOLUME).
struct StatBlock: View {

    let label: String
    let value: String
    var tint: Color = AppTheme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 14, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(AppTheme.textMuted)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Ratio bar

/// Thin two-tone horizontal bar showing a bid/ask or buy/sell balance.
/// `ratio` is the green share in 0…1; the remainder renders red.
struct RatioBar: View {

    /// Fraction of the bar drawn in `upColor`, clamped to 0…1.
    let ratio: Double
    var upColor: Color = AppTheme.candleUp
    var downColor: Color = AppTheme.candleDown
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(ratio, 0), 1)
            HStack(spacing: 2) {
                Capsule()
                    .fill(upColor)
                    .frame(width: max(geo.size.width * clamped - 1, 0))
                Capsule()
                    .fill(downColor)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.25), value: ratio)
    }
}
