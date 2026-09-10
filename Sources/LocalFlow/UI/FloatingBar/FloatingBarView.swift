import SwiftUI
import AppKit

/// Reports the floating bar's ideal size so the panel can size itself to the
/// content instead of guessing a width per state.
struct FloatingBarSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

public struct FloatingBarView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var settingsManager = SettingsManager.shared

    /// Transparent margin kept around the bar so its shadow is not clipped by
    /// the panel and so the glass edge never touches the window bounds.
    static let shadowInset: CGFloat = 20

    private let onSizeChange: (CGSize) -> Void

    @State private var pulse = false

    public init(onSizeChange: @escaping (CGSize) -> Void = { _ in }) {
        self.onSizeChange = onSizeChange
    }

    private var compact: Bool {
        settingsManager.settings.floatingBarSize.isCompact
    }

    public var body: some View {
        bar
            .padding(Self.shadowInset)
            .fixedSize()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: FloatingBarSizeKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(FloatingBarSizeKey.self) { size in
                guard size.width > 0, size.height > 0 else { return }
                onSizeChange(size)
            }
    }

    private var bar: some View {
        content
            .padding(.horizontal, compact ? DS.Spacing.m : DS.Spacing.l)
            .padding(.vertical, compact ? DS.Spacing.s : 10)
            .background(glass)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous))
            .shadow(color: .black.opacity(0.42), radius: 24, x: 0, y: 10)
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 1)
            .animation(DS.Motion.bar, value: appState.dictationState)
    }

    @ViewBuilder
    private var content: some View {
        switch appState.dictationState {
        case .idle:
            EmptyView()
        case .preparing:
            preparingView
        case .listening:
            listeningView
        case .processing(let stage):
            processingView(stage: stage)
        case .success:
            successView
        case .error(let message):
            errorView(message: message)
        case .cancelled:
            cancelledView
        }
    }

    // MARK: - Chrome

    private var glass: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.62),
                            Color(red: 0.07, green: 0.07, blue: 0.10).opacity(0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
        }
    }

    // MARK: - Preparing

    private var preparingView: some View {
        HStack(spacing: DS.Spacing.s) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
            Text("Starting…")
                .font(DS.Font.barTitle(compact))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Listening

    private var listeningView: some View {
        HStack(spacing: compact ? DS.Spacing.s : DS.Spacing.m) {
            recordingDot

            AudioWaveformView(level: appState.audioLevel, isProcessing: false, compact: compact)

            elapsedLabel

            if !compact {
                separator
                targetAppLabel
            }

            if appState.isHandsFreeActive {
                StatusChip("HANDS-FREE", kind: .neutral)
                    .environment(\.colorScheme, .dark)
            }

            Spacer(minLength: DS.Spacing.s)

            listeningActions
        }
    }

    private var recordingDot: some View {
        ZStack {
            Circle()
                .fill(DS.Palette.recording.opacity(0.32))
                .frame(width: 18, height: 18)
                .scaleEffect(pulse ? 1.5 : 1.0)
                .opacity(pulse ? 0.0 : 0.9)

            Circle()
                .fill(DS.Palette.recording)
                .frame(width: 8, height: 8)
                .shadow(color: DS.Palette.recording.opacity(0.8), radius: 4)
        }
        .frame(width: 18, height: 18)
        .onAppear {
            guard let animation = DS.Motion.ambient(1.1, autoreverses: false) else { return }
            withAnimation(animation) { pulse = true }
        }
        .accessibilityLabel("Recording")
    }

    /// Elapsed recording time. Long dictations are easy to lose track of, so the
    /// bar always says how long the microphone has been open.
    private var elapsedLabel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text(elapsedText)
                .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var elapsedText: String {
        let seconds = Int(appState.recordingDuration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(width: 1, height: 16)
    }

    private var targetAppLabel: some View {
        HStack(spacing: DS.Spacing.xs + 1) {
            if let icon = appState.activeAppIcon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
            }
            Text(appState.activeAppName.isEmpty ? "Dictation" : appState.activeAppName)
                .font(DS.Font.barTitle(compact))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var listeningActions: some View {
        HStack(spacing: DS.Spacing.s) {
            BarIconButton(
                systemImage: "checkmark",
                tint: DS.Palette.success,
                prominent: true,
                help: "Stop and insert"
            ) {
                appState.stopListeningAndProcess()
            }

            BarIconButton(
                systemImage: "xmark",
                tint: .white.opacity(0.55),
                prominent: false,
                help: "Cancel (esc)"
            ) {
                appState.cancel()
            }
        }
    }

    // MARK: - Processing

    private func processingView(stage: DictationState.ProcessingStage) -> some View {
        HStack(spacing: DS.Spacing.m) {
            AudioWaveformView(level: 0, isProcessing: true, compact: compact)

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.title)
                    .font(DS.Font.barTitle(compact))
                    .foregroundStyle(.white)

                if !compact {
                    Text("On-device · Neural Engine")
                        .font(DS.Font.barCaption(compact))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            stageTrack(current: stage)
        }
    }

    /// Three-segment track showing which pipeline stage is running, so a slow
    /// transcription never looks like a hang.
    private func stageTrack(current: DictationState.ProcessingStage) -> some View {
        HStack(spacing: 4) {
            ForEach(DictationState.ProcessingStage.ordered, id: \.self) { stage in
                Capsule()
                    .fill(Color.white.opacity(stage.order <= current.order ? 0.85 : 0.20))
                    .frame(width: stage == current ? 14 : 7, height: 3)
            }
        }
        .animation(DS.Motion.bar, value: current)
    }

    // MARK: - Success

    private var successView: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: compact ? 15 : 17, weight: .bold))
                .foregroundStyle(DS.Palette.success)

            VStack(alignment: .leading, spacing: 1) {
                Text("Inserted")
                    .font(DS.Font.barTitle(compact))
                    .foregroundStyle(.white)

                if settingsManager.settings.showLiveTranscript, !transcriptPreview.isEmpty {
                    Text(transcriptPreview)
                        .font(DS.Font.barCaption(compact))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .frame(maxWidth: 320, alignment: .leading)
                }
            }
        }
    }

    private var transcriptPreview: String {
        let text = appState.lastTranscribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 60 else { return text }
        return String(text.prefix(60)) + "…"
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        Group {
            if DictationState.isAccessibilityMessage(message) {
                HStack(spacing: DS.Spacing.m) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Palette.warning)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Accessibility access required")
                            .font(DS.Font.barTitle(compact))
                            .foregroundStyle(.white)
                        Text("LocalFlow needs permission to type into other apps.")
                            .font(DS.Font.barCaption(compact))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Button {
                        AccessibilityManager.shared.openSystemSettings()
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DS.Palette.warning, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: DS.Spacing.s) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Palette.warning)
                    Text(message)
                        .font(DS.Font.barTitle(compact))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(maxWidth: 320, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Cancelled

    private var cancelledView: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
            Text("Cancelled")
                .font(DS.Font.barTitle(compact))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - Bar button

/// Circular action button sized for the floating bar's hit targets.
private struct BarIconButton: View {
    let systemImage: String
    let tint: Color
    let prominent: Bool
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(prominent ? tint.opacity(isHovering ? 0.32 : 0.20) : Color.white.opacity(isHovering ? 0.16 : 0.08))
                    .frame(width: 22, height: 22)
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(tint)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(help)
        .onHover { isHovering = $0 }
        .animation(DS.Motion.reactive, value: isHovering)
        .accessibilityLabel(help)
    }
}
