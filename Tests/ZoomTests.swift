import Testing
import Foundation
@testable import BitcoinTerminal

// MARK: - Test helpers

/// Build a synthetic `Kline` at minute offset `i` from the epoch.
@MainActor
private func makeKline(index i: Int) -> Kline {
    Kline(
        openTime: Date(timeIntervalSince1970: Double(i) * 60),
        open: Decimal(100 + i),
        high: Decimal(105 + i),
        low: Decimal(95 + i),
        close: Decimal(102 + i),
        volume: Decimal(10),
        closeTime: Date(timeIntervalSince1970: Double(i) * 60 + 59),
        isClosed: true
    )
}

@Suite("Zoom")
@MainActor
struct ZoomTests {

    /// Build a `ChartViewModel` with `klineCount` pre-loaded historical klines.
    private func makeViewModel(klineCount: Int) -> ChartViewModel {
        let vm = ChartViewModel(service: StubExchangeService())
        let klines: [Kline] = (0..<klineCount).map { makeKline(index: $0) }
        vm.klineStore.loadHistorical(klines)
        return vm
    }

    // MARK: - Default zoom

    @Test func defaultZoomReturnsAllKlines() {
        let vm = makeViewModel(klineCount: 100)
        #expect(vm.visibleKlines.count == 100)
        #expect(vm.zoomLevel == 0)
    }

    // MARK: - Zoom in

    @Test func zoomInReducesVisibleCount() {
        let vm = makeViewModel(klineCount: 100)
        vm.zoomIn()
        #expect(vm.visibleKlines.count < 100)
        #expect(vm.zoomLevel == 1)
    }

    // MARK: - Zoom out

    @Test func zoomOutShowsMoreCandles() {
        let vm = makeViewModel(klineCount: 100)
        // Zoom in twice so we have room to zoom back out.
        vm.zoomIn()
        vm.zoomIn()
        let zoomedInCount = vm.visibleKlines.count
        vm.zoomOut()
        #expect(vm.visibleKlines.count > zoomedInCount)
    }

    // MARK: - Bounds clamping

    @Test func zoomInClampsAtMaxLevel() {
        let vm = makeViewModel(klineCount: 500)
        for _ in 0..<10 { vm.zoomIn() }
        #expect(vm.zoomLevel == 5)
    }

    @Test func zoomOutClampsAtMinLevel() {
        let vm = makeViewModel(klineCount: 100)
        for _ in 0..<10 { vm.zoomOut() }
        #expect(vm.zoomLevel == -3)
    }

    // MARK: - Visible count invariants

    @Test func visibleCountNeverBelowMinimum() {
        let vm = makeViewModel(klineCount: 500)
        for _ in 0..<10 { vm.zoomIn() }
        #expect(vm.visibleKlines.count >= 20)
    }

    @Test func visibleCountNeverExceedsTotal() {
        let vm = makeViewModel(klineCount: 50)
        for _ in 0..<10 { vm.zoomOut() }
        #expect(vm.visibleKlines.count == 50)
    }

    // MARK: - Empty store

    @Test func emptyStoreReturnsEmptyVisible() {
        let vm = makeViewModel(klineCount: 0)
        #expect(vm.visibleKlines.isEmpty)
    }

    // MARK: - Crosshair remapping

    @Test func crosshairClampsOnZoomIn() {
        let vm = makeViewModel(klineCount: 100)
        vm.enterExploration()
        // Crosshair should start at the last visible index (at zoomLevel == 0, that's 99).
        #expect(vm.crosshairIndex == vm.visibleKlines.count - 1)
        vm.zoomIn()
        let maxIdx = vm.visibleKlines.count - 1
        #expect((vm.crosshairIndex ?? 0) <= maxIdx)
    }

    @Test func enterExplorationSetsLastVisibleIndex() {
        let vm = makeViewModel(klineCount: 100)
        vm.zoomIn()   // visibleKlines.count < 100
        vm.enterExploration()
        #expect(vm.crosshairIndex == vm.visibleKlines.count - 1)
        #expect(vm.isExploring)
    }

    // MARK: - visibleKlines is a suffix of klineStore.klines

    @Test func visibleKlinesIsSuffix() {
        let vm = makeViewModel(klineCount: 100)
        vm.zoomIn()
        let visible = vm.visibleKlines
        let full = vm.klineStore.klines
        // Suffix means the last element of visible equals the last element of full.
        #expect(visible.last?.openTime == full.last?.openTime)
    }
}
