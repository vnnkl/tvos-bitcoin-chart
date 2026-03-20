import SwiftUI

/// Central dark-theme palette and TV-appropriate sizing constants.
///
/// All values are static constants — never instantiated — so SwiftUI views
/// reference them as `AppTheme.candleUp`, `AppTheme.edgePadding`, etc.
enum AppTheme {

    // MARK: - Background

    /// Primary app background: absolute black for OLED-optimal contrast.
    static let background = Color.black

    // MARK: - Candle Colors

    /// Up candle (close > open): bright green, visible at TV viewing distance.
    static let candleUp   = Color(red: 0.0,  green: 0.784, blue: 0.325)  // #00C853

    /// Down candle (close < open): bright red.
    static let candleDown = Color(red: 1.0,  green: 0.090, blue: 0.267)  // #FF1744

    /// Doji / unchanged candle: neutral gray.
    static let candleDoji = Color(white: 0.5)

    // MARK: - Text Colors

    static let textPrimary   = Color.white
    static let textSecondary = Color(white: 0.6)

    // MARK: - Connection State Colors

    static let stateConnected     = Color.green
    static let stateConnecting    = Color.yellow
    static let stateReconnecting  = Color.orange
    static let stateDisconnected  = Color.red

    // MARK: - Typography

    /// Minimum font for body / secondary text — legible at 10 ft.
    static let bodyFont: Font    = .title3
    /// Prominent price displays.
    static let priceFont: Font   = .title
    /// Headlines and section titles.
    static let headlineFont: Font = .title2

    // MARK: - Layout

    /// Horizontal edge padding — meets the tvOS 60 pt safe-area convention.
    static let edgePadding: CGFloat = 60

    /// Vertical spacing between major UI sections.
    static let sectionSpacing: CGFloat = 24

    // MARK: - Chart

    /// Minimum pixel width per candle body (exclusive of spacing).
    static let candleMinWidth: CGFloat  = 4
    /// Gap between adjacent candle bodies.
    static let candleSpacing: CGFloat   = 2
    /// Volume bar height as a fraction of the total chart height.
    static let volumeHeightRatio: CGFloat = 0.2

    // MARK: - Sidebar

    /// Fixed width for the right-side trading panel (order book + trades feed).
    static let sidebarWidth: CGFloat = 340

    // MARK: - Corner Radii

    static let cardCornerRadius: CGFloat   = 12
    static let badgeCornerRadius: CGFloat  = 8

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
