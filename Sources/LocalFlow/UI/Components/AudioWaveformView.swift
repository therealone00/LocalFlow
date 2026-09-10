import SwiftUI

/// Live audio meter for the floating bar.
///
/// While listening it scrolls a rolling history of microphone levels from right
/// to left, so the bar reflects what was actually said rather than animating
/// decoratively. While processing it plays an indeterminate travelling wave.
public struct AudioWaveformView: View {
    public let level: Float
    public let isProcessing: Bool
    public let compact: Bool

    @State private var history: [CGFloat] = []

    private var barCount: Int { compact ? 12 : 16 }
    private var barWidth: CGFloat { compact ? 2.5 : 3 }
    private var barSpacing: CGFloat { compact ? 2 : 2.5 }
    private var maxHeight: CGFloat { compact ? 16 : 22 }
    private var minHeight: CGFloat { barWidth }

    private var totalWidth: CGFloat {
        CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
    }

    public init(level: Float, isProcessing: Bool = false, compact: Bool = false) {
        self.level = level
        self.isProcessing = isProcessing
        self.compact = compact
    }

    public var body: some View {
        Group {
            if isProcessing {
                processingWave
            } else {
                liveWave
            }
        }
        .frame(width: totalWidth, height: maxHeight)
        .accessibilityHidden(true)
    }

    // MARK: - Listening

    private var liveWave: some View {
        Canvas { context, size in
            let bars = paddedHistory
            draw(bars, in: &context, size: size, gradient: liveGradient)
        }
        .onAppear { history = Array(repeating: 0, count: barCount) }
        .onChange(of: level) { _, newLevel in
            push(CGFloat(newLevel))
        }
    }

    /// Levels arrive faster than the eye can follow, so the history is capped at
    /// `barCount` samples and the newest sample is appended on the right.
    private func push(_ value: CGFloat) {
        var next = history
        if next.count != barCount {
            next = Array(repeating: 0, count: barCount)
        }
        next.removeFirst()
        // A gentle curve keeps quiet speech visible without clipping loud speech.
        next.append(min(1, pow(max(0, value), 0.65)))
        history = next
    }

    private var paddedHistory: [CGFloat] {
        history.count == barCount ? history : Array(repeating: 0, count: barCount)
    }

    // MARK: - Processing

    private var processingWave: some View {
        Group {
            if DS.Motion.isReduced {
                Canvas { context, size in
                    draw(Array(repeating: 0.45, count: barCount), in: &context, size: size, gradient: processingGradient)
                }
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        let bars = (0..<barCount).map { index -> CGFloat in
                            let phase = Double(index) * 0.55 - t * 5.0
                            return 0.25 + 0.6 * (0.5 + 0.5 * sin(phase))
                        }
                        draw(bars, in: &context, size: size, gradient: processingGradient)
                    }
                }
            }
        }
    }

    // MARK: - Drawing

    private var liveGradient: GraphicsContext.Shading {
        .linearGradient(
            Gradient(colors: [DS.Palette.coral, DS.Palette.violet, DS.Palette.cyan]),
            startPoint: CGPoint(x: 0, y: maxHeight),
            endPoint: .zero
        )
    }

    private var processingGradient: GraphicsContext.Shading {
        .linearGradient(
            Gradient(colors: [DS.Palette.cyan, DS.Palette.violet, DS.Palette.coral]),
            startPoint: .zero,
            endPoint: CGPoint(x: totalWidth, y: 0)
        )
    }

    private func draw(
        _ bars: [CGFloat],
        in context: inout GraphicsContext,
        size: CGSize,
        gradient: GraphicsContext.Shading
    ) {
        var path = Path()
        for (index, value) in bars.enumerated() {
            let height = max(minHeight, min(maxHeight, value * maxHeight))
            let x = CGFloat(index) * (barWidth + barSpacing)
            let y = (size.height - height) / 2
            path.addRoundedRect(
                in: CGRect(x: x, y: y, width: barWidth, height: height),
                cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2)
            )
        }
        context.fill(path, with: gradient)
    }
}
