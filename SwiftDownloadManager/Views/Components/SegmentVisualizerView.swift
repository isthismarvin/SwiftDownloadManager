import SwiftUI

struct SegmentVisualizerView: View {
    let segments: [DownloadSegment]
    var bytesTotal: Int64 = 0
    var downloadCompleted: Bool = false

    private var sortedSegments: [DownloadSegment] {
        segments.sorted(by: { $0.index < $1.index })
    }

    private var completedCount: Int {
        sortedSegments.filter(\.isCompleted).count
    }

    private var overallProgress: Double {
        guard !sortedSegments.isEmpty else { return 0 }
        let totalProgress = sortedSegments.reduce(0.0) { partial, segment in
            partial + segment.displayProgress(bytesTotal: bytesTotal, downloadCompleted: downloadCompleted)
        }
        return totalProgress / Double(sortedSegments.count)
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(sortedSegments) { segment in
                GeometryReader { geo in
                    let progress = segment.displayProgress(
                        bytesTotal: bytesTotal,
                        downloadCompleted: downloadCompleted
                    )

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))

                        Rectangle()
                            .fill(segment.isCompleted || downloadCompleted ? Color.green : Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(min(max(progress, 0.0), 1.0)))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                }
                .frame(height: 4)
            }
        }
        .frame(height: 4)
        .accessibilityLabel(
            L10n.t(
                de: "Segment-Fortschritt: \(completedCount) von \(sortedSegments.count) abgeschlossen, \(Int(overallProgress * 100)) Prozent",
                en: "Segment progress: \(completedCount) of \(sortedSegments.count) completed, \(Int(overallProgress * 100)) percent"
            )
        )
    }
}
