import SwiftUI

struct RSIGaugeView: View {

    let klines: [Kline]

    private var series: [IndicatorValue] {
        rsi(klines: klines, period: 14)
    }

    private var latestValueText: String {
        guard let latest = series.last?.value else { return "--" }
        return NSDecimalNumber(decimal: latest).rounding(accordingToBehavior: nil).stringValue
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.surface)

            Canvas { context, size in
                guard series.count >= 2 else { return }

                let layout = CandleLayout(count: klines.count, width: size.width)

                for level in [Decimal(30), Decimal(50), Decimal(70)] {
                    let y = oscillatorY(level, in: size.height)
                    var guide = Path()
                    guide.move(to: CGPoint(x: 0, y: y))
                    guide.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(
                        guide,
                        with: .color(AppTheme.textMuted.opacity(level == 50 ? 0.45 : 0.25)),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 6])
                    )
                }

                var path = Path()
                let startIndex = klines.count - series.count

                for (offset, point) in series.enumerated() {
                    let x = layout.centerX(for: startIndex + offset)
                    let y = oscillatorY(point.value, in: size.height)
                    if offset == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color(AppTheme.indicatorRSI),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)

            HStack(spacing: 8) {
                Text("RSI")
                    .font(AppTheme.dataHeaderFont)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(latestValueText)
                    .font(AppTheme.dataFont)
                    .foregroundStyle(AppTheme.indicatorRSI)

                Spacer()

                Text("70 / 30")
                    .font(AppTheme.dataHeaderFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func oscillatorY(_ value: Decimal, in height: CGFloat) -> CGFloat {
        let scalar = CGFloat(NSDecimalNumber(decimal: value).doubleValue / 100)
        return height - (scalar * height)
    }
}

struct MACDPanelView: View {

    let klines: [Kline]

    private var series: MACDSeries {
        macd(klines: klines, fast: 12, slow: 26, signal: 9)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.surface)

            Canvas { context, size in
                guard !series.line.isEmpty else { return }

                let layout = CandleLayout(count: klines.count, width: size.width)
                let maxMagnitude = maximumMagnitude(in: series)
                guard maxMagnitude > 0 else { return }

                let zeroY = macdY(.zero, in: size.height, maxMagnitude: maxMagnitude)
                var zeroLine = Path()
                zeroLine.move(to: CGPoint(x: 0, y: zeroY))
                zeroLine.addLine(to: CGPoint(x: size.width, y: zeroY))
                context.stroke(zeroLine, with: .color(AppTheme.textMuted.opacity(0.45)), lineWidth: 1)

                let histogramStart = klines.count - series.histogram.count
                for (offset, point) in series.histogram.enumerated() {
                    let centerX = layout.centerX(for: histogramStart + offset)
                    let valueY = macdY(point.value, in: size.height, maxMagnitude: maxMagnitude)
                    let rect = CGRect(
                        x: centerX - (layout.bodyWidth / 2),
                        y: min(zeroY, valueY),
                        width: layout.bodyWidth,
                        height: max(abs(zeroY - valueY), 1)
                    )
                    let color = point.value >= 0 ? AppTheme.candleUp : AppTheme.candleDown
                    context.fill(Path(rect), with: .color(color.opacity(0.7)))
                }

                stroke(
                    context: &context,
                    size: size,
                    layout: layout,
                    series: series.line,
                    color: AppTheme.indicatorMACD,
                    maxMagnitude: maxMagnitude
                )

                stroke(
                    context: &context,
                    size: size,
                    layout: layout,
                    series: series.signal,
                    color: AppTheme.indicatorSignal,
                    maxMagnitude: maxMagnitude
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)

            Text("MACD")
                .font(AppTheme.dataHeaderFont)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func stroke(
        context: inout GraphicsContext,
        size: CGSize,
        layout: CandleLayout,
        series: [IndicatorValue],
        color: Color,
        maxMagnitude: Decimal
    ) {
        guard series.count >= 2 else { return }

        let startIndex = klines.count - series.count
        var path = Path()

        for (offset, point) in series.enumerated() {
            let x = layout.centerX(for: startIndex + offset)
            let y = macdY(point.value, in: size.height, maxMagnitude: maxMagnitude)

            if offset == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
    }

    private func maximumMagnitude(in series: MACDSeries) -> Decimal {
        let values = (series.line + series.signal + series.histogram).map(\.value)
        return values.reduce(.zero) { current, next in
            max(current, absolute(next))
        }
    }

    private func absolute(_ value: Decimal) -> Decimal {
        value >= 0 ? value : -value
    }

    private func macdY(_ value: Decimal, in height: CGFloat, maxMagnitude: Decimal) -> CGFloat {
        let valueScalar = NSDecimalNumber(decimal: value).doubleValue
        let maxScalar = max(NSDecimalNumber(decimal: maxMagnitude).doubleValue, 0.0001)
        let normalized = valueScalar / maxScalar
        return height / 2 - (CGFloat(normalized) * height * 0.42)
    }
}
