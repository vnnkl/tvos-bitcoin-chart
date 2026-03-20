import SwiftUI

/// Central dark-theme palette and TV-appropriate sizing constants.
///
/// All values are static constants — never instantiated — so SwiftUI views
/// reference them as `AppTheme.candleUp`, `AppTheme.edgePadding`, etc.
enum AppTheme {

    // MARK: - Background

    /// Primary app background: absolute black for OLED-optimal contrast.
    static let background = Color.black

    /// Slightly lifted surface for cards and sidebar panels.
    static let surface = Color(white: 0.06)

    /// Subtle separator lines between zones.
    static let separator = Color(white: 0.15)

    // MARK: - Candle Colors

    /// Up candle (close > open): bright green, visible at TV viewing distance.
    static let candleUp   = Color(red: 0.0,  green: 0.784, blue: 0.325)  // #00C853

    /// Down candle (close < open): bright red.
    static let candleDown = Color(red: 1.0,  green: 0.090, blue: 0.267)  // #FF1744

    /// Doji / unchanged candle: neutral gray.
    static let candleDoji = Color(white: 0.5)

    // MARK: - Text Colors

    static let textPrimary   = Color.white
    static let textSecondary = Color(white: 0.45)
    static let textMuted     = Color(white: 0.30)

    // MARK: - Connection State Colors

    static let stateConnected     = Color.green
    static let stateConnecting    = Color.yellow
    static let stateReconnecting  = Color.orange
    static let stateDisconnected  = Color.red

    // MARK: - Typography

    /// Compact data font for sidebar numerical tables — smaller than title3
    /// to fit price/qty columns without truncation at TV distance.
    static let dataFont: Font     = .system(size: 22, weight: .medium, design: .monospaced)
    /// Column header labels in tables.
    static let dataHeaderFont: Font = .system(size: 18, weight: .semibold, design: .monospaced)
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

    static let cardCornerRadius: CGFloat   = 12
    static let badgeCornerRadius: CGFloat  = 8

    // MARK: - STRC Dashboard

    /// ATM Active status badge: green — company is actively issuing shares.
    static let strcATMActive      = Color(red: 0.0,  green: 0.784, blue: 0.325)  // same as candleUp
    /// ATM Standby status badge: yellow — share price is below par value.
    static let strcATMStandby     = Color(red: 1.0,  green: 0.9,   blue: 0.0)
    /// Dark card surface for STRC dashboard sections.
    static let strcCardBackground = Color(white: 0.1)
    /// Blue accent for highlights and labels on the STRC tab.
    static let strcAccent         = Color(red: 0.2,  green: 0.6,   blue: 1.0)

    // MARK: - Alerts

    /// Horizontal alert threshold line on the chart canvas.
    static let alertLine   = Color.yellow

    /// Alert firing banner background (orange — distinct from yellow line).
    static let alertBanner = Color(red: 1.0, green: 0.6, blue: 0.0)

    // MARK: - Axes

    /// Compact monospaced font for price and time axis labels — legible at TV distance.
    static let axisFont: Font = .system(size: 18, weight: .medium, design: .monospaced)

    /// Subtle gray for axis tick labels — matches `textSecondary` lightness.
    static let axisLabelColor: Color = Color(white: 0.45)

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
