import SwiftUI
import Charts

struct SpeedChartView: View {
    let samples: [SpeedSample]
    let caption: String
    var isHistorical: Bool = false

    private struct ChartPoint: Identifiable {
        let id: Int
        let elapsed: TimeInterval
        let speedMBps: Double
    }

    private var chartPoints: [ChartPoint] {
        let source = samples.isEmpty
            ? [SpeedSample(date: Date(), speedBytesPerSecond: 0)]
            : samples
        let start = source.first?.date ?? Date()
        return source.enumerated().map { index, sample in
            ChartPoint(
                id: index,
                elapsed: sample.date.timeIntervalSince(start),
                speedMBps: sample.speedBytesPerSecond / 1_000_000
            )
        }
    }

    private var maxSpeedMBps: Double {
        let maxBytes = samples.map(\.speedBytesPerSecond).max() ?? 0
        let mbps = maxBytes / 1_000_000
        return max((mbps * 1.25).rounded(.up), 1)
    }

    private var chartTint: Color {
        isHistorical ? .green : .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.t(de: "Geschwindigkeit", en: "Speed"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(caption)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(chartTint)
                    .lineLimit(1)
            }

            Chart(chartPoints) { point in
                AreaMark(
                    x: .value("Elapsed", point.elapsed),
                    y: .value("MB/s", point.speedMBps)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartTint.opacity(0.22), chartTint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Elapsed", point.elapsed),
                    y: .value("MB/s", point.speedMBps)
                )
                .foregroundStyle(chartTint)
                .lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...maxSpeedMBps)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let elapsed = value.as(TimeInterval.self) {
                            Text(TimeFormatter.formatDuration(elapsed))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, maxSpeedMBps / 2, maxSpeedMBps]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel {
                        if let mbps = value.as(Double.self) {
                            Text("\(Int(mbps))")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                }
        }
        .accessibilityLabel(
            L10n.t(
                de: "Geschwindigkeitsverlauf: \(caption)",
                en: "Speed history: \(caption)"
            )
        )
    }
}
