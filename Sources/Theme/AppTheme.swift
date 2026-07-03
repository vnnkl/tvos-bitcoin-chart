import SwiftUI

/// Central dark-theme palette and TV-appropriate sizing constants.
///
/// Design language: "OLED trading desk" — absolute black canvas, hairline-stroked
/// panels, Bitcoin-orange as the single accent for selection/focus, and refined
/// market green/red reserved exclusively for direction semantics.
///
/// All values are static constants — never instantiated — so SwiftUI views
/// reference them as `AppTheme.candleUp`, `AppTheme.edgePadding`, etc.
enum AppTheme {

    // MARK: - Background & Surfaces

    /// Primary app background: absolute black for OLED-optimal contrast.
    static let background = Color.black

    /// Slightly lifted surface for cards and sidebar panels (cool near-black).
    static let surface = Color(red: 0.043, green: 0.051, blue: 0.063)   // ≈ #0B0D10

    /// Panel card fill — one step above `surface`, used behind data zones.
    static let panel = Color(red: 0.055, green: 0.063, blue: 0.078)     // ≈ #0E1014

    /// Hairline stroke around panel cards.
    static let panelStroke = Color(white: 1.0).opacity(0.08)

    /// Subtle separator lines between zones.
    static let separator = Color(white: 0.16)

    // MARK: - Accent

    /// Signature accent: Bitcoin orange. Used for selection, focus, and brand
    /// identity — never for market direction (that's `candleUp`/`candleDown`).
    static let accent = Color(red: 0.969, green: 0.576, blue: 0.102)    // #F7931A

    /// Soft accent fill for selected-row backgrounds.
    static let accentSoft = accent.opacity(0.16)

    // MARK: - Candle Colors

    /// Up candle (close > open): refined market green — bright at TV distance
    /// without the neon glare of a pure RGB green.
    static let candleUp   = Color(red: 0.180, green: 0.741, blue: 0.522)  // #2EBD85

    /// Down candle (close < open): refined market red.
    static let candleDown = Color(red: 0.965, green: 0.275, blue: 0.365)  // #F6465D

    /// Doji / unchanged candle: neutral gray.
    static let candleDoji = Color(white: 0.5)

    static let indicatorEMA    = Color(red: 0.96, green: 0.77, blue: 0.16)
    static let indicatorSMA    = Color(red: 0.54, green: 0.74, blue: 0.98)
    static let indicatorRSI    = Color(red: 0.98, green: 0.56, blue: 0.22)
    static let indicatorMACD   = Color(red: 0.35, green: 0.82, blue: 0.67)
    static let indicatorSignal = Color(red: 0.98, green: 0.84, blue: 0.35)

    // MARK: - Text Colors

    static let textPrimary   = Color.white
    static let textSecondary = Color(white: 0.58)
    static let textMuted     = Color(white: 0.38)

    // MARK: - Connection State Colors

    static let stateConnected     = candleUp
    static let stateConnecting    = Color.yellow
    static let stateReconnecting  = Color.orange
    static let stateDisconnected  = candleDown

    // MARK: - Typography

    /// Compact data font for sidebar numerical tables — smaller than title3
    /// to fit price/qty columns without truncation at TV distance.
    static let dataFont: Font     = .system(size: 22, weight: .medium, design: .monospaced)
    /// Column header labels in tables.
    static let dataHeaderFont: Font = .system(size: 17, weight: .semibold, design: .monospaced)
    /// Uppercase tracked micro-labels above panels ("ORDER BOOK", "TRADES").
    static let microLabelFont: Font = .system(size: 16, weight: .bold)
    /// Tracking applied to micro-labels.
    static let microLabelTracking: CGFloat = 2.4
    /// Minimum font for body / secondary text — legible at 10 ft.
    static let bodyFont: Font     = .title3
    /// Prominent price displays.
    static let priceFont: Font    = .title
    /// Headlines and section titles.
    static let headlineFont: Font = .title2

    // MARK: - Layout

    /// Horizontal edge padding — meets the tvOS 60 pt safe-area convention.
    static let edgePadding: CGFloat = 60

    /// Vertical spacing between major UI sections.
    static let sectionSpacing: CGFloat = 20

    // MARK: - Chart

    /// Minimum pixel width per candle body (exclusive of spacing).
    static let candleMinWidth: CGFloat  = 4
    /// Gap between adjacent candle bodies.
    static let candleSpacing: CGFloat   = 2
    /// Volume bar height as a fraction of the total chart height.
    static let volumeHeightRatio: CGFloat = 0.18

    // MARK: - Sidebar

    /// Fixed width for the right-side trading panel (order book + trades feed).
    static let sidebarWidth: CGFloat = 420

    // MARK: - Corner Radii

    static let panelCornerRadius: CGFloat  = 14
    static let cardCornerRadius: CGFloat   = 12
    static let badgeCornerRadius: CGFloat  = 8

    // MARK: - STRC Dashboard

    /// ATM Active status badge: green — company is actively issuing shares.
    static let strcATMActive      = candleUp
    /// ATM Standby status badge: yellow — share price is below par value.
    static let strcATMStandby     = Color(red: 1.0,  green: 0.9,   blue: 0.0)
    /// Dark card surface for STRC dashboard sections.
    static let strcCardBackground = panel
    /// Blue accent for highlights and labels on the STRC tab.
    static let strcAccent         = Color(red: 0.35, green: 0.64, blue: 1.0)

    // MARK: - Alerts

    /// Horizontal alert threshold line on the chart canvas.
    static let alertLine   = Color.yellow

    /// Alert firing banner background (orange — distinct from yellow line).
    static let alertBanner = Color(red: 1.0, green: 0.6, blue: 0.0)

    // MARK: - Axes

    /// Compact monospaced font for price and time axis labels — legible at TV distance.
    static let axisFont: Font = .system(size: 18, weight: .medium, design: .monospaced)

    /// Subtle gray for axis tick labels — matches `textSecondary` lightness.
    static let axisLabelColor: Color = Color(white: 0.55)

    /// Reserved width on the right edge for the price Y-axis panel.
    static let priceAxisWidth: CGFloat = 90

    /// Height of the time X-axis bar below the chart area.
    static let timeAxisHeight: CGFloat = 30

    // MARK: - Heatmap

    /// Near-black dark blue — lowest liquidity (cold end of thermal palette).
    static let heatmapCold    = Color(red: 0.0, green: 0.0, blue: 0.15)
    /// Blue — low liquidity.
    static let heatmapCool    = Color(red: 0.0, green: 0.0, blue: 0.6)
    /// Teal-green — moderate liquidity.
    static let heatmapMedium  = Color(red: 0.0, green: 0.6, blue: 0.3)
    /// Green — above-average liquidity.
    static let heatmapWarm    = Color(red: 0.0, green: 0.8, blue: 0.0)
    /// Yellow — high liquidity.
    static let heatmapHot     = Color(red: 1.0, green: 0.9, blue: 0.0)
    /// White — extreme liquidity walls (hottest end of thermal palette).
    static let heatmapExtreme = Color(red: 1.0, green: 1.0, blue: 1.0)

    /// Opacity used when compositing the heatmap behind candlesticks.
    static let heatmapOpacity: Double = 0.6
}
