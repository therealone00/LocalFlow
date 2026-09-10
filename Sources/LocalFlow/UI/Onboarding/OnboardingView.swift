import SwiftUI

/// Ordered setup steps. Using a named enum instead of loose integers keeps the
/// progress indicator, the navigation and the gating rules in sync.
public enum OnboardingStep: Int, CaseIterable, Identifiable, Comparable {
    case welcome
    case privacy
    case microphone
    case accessibility
    case shortcut
    case model
    case test
    case finish

    public var id: Int { rawValue }

    public static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}

public struct OnboardingView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var micManager = MicrophoneAccessManager.shared
    @ObservedObject var axManager = AccessibilityManager.shared
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var appState = AppState.shared

    @State private var step: OnboardingStep = .welcome
    @State private var testInputText: String = ""
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            progressBar

            VStack(spacing: DS.Spacing.l) {
                Spacer(minLength: 0)
                stepContent
                    .frame(maxWidth: 460)
                    .id(step)
                    .transition(.opacity)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, DS.Spacing.xxl)

            footer
        }
        .frame(width: 640, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        // Permission steps advance on their own once the user grants access in
        // System Settings, so nobody is left staring at a disabled button.
        .onChange(of: micManager.isGranted) { _, granted in
            if granted, step == .microphone { advance() }
        }
        .onChange(of: axManager.isTrusted) { _, trusted in
            if trusted, step == .accessibility { advance() }
        }
    }

    // MARK: - Chrome

    private var progressBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(OnboardingStep.allCases) { candidate in
                Capsule()
                    .fill(candidate <= step ? Color.accentColor : Color.secondary.opacity(0.22))
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.l)
        .animation(DS.Motion.page, value: step)
    }

    private var footer: some View {
        HStack(spacing: DS.Spacing.m) {
            if let previous = step.previous, step != .finish {
                Button("Back") {
                    withAnimation(DS.Motion.page) { step = previous }
                }
            }

            Spacer()

            if isSkippable {
                Button("Skip") { advance() }
                    .buttonStyle(.link)
            }

            if step == .finish {
                Button("Start Dictating") { finish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue") { advance() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canProceed)
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, DS.Spacing.xl)
    }

    /// Steps the user may pass without completing. Permissions are not on this
    /// list because the app genuinely cannot work without them.
    private var isSkippable: Bool {
        step == .model && !modelManager.isModelDownloaded(tier: settingsManager.settings.speechModelTier)
            || step == .test
    }

    private var canProceed: Bool {
        switch step {
        case .microphone: return micManager.isGranted
        case .accessibility: return axManager.isTrusted
        case .model: return modelManager.isModelDownloaded(tier: settingsManager.settings.speechModelTier)
        default: return true
        }
    }

    private func advance() {
        guard let next = step.next else { return }
        withAnimation(DS.Motion.page) { step = next }
    }

    private func finish() {
        settingsManager.settings.hasCompletedOnboarding = true
        dismiss()
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: welcomeStep
        case .privacy: privacyStep
        case .microphone: microphoneStep
        case .accessibility: accessibilityStep
        case .shortcut: shortcutStep
        case .model: modelStep
        case .test: testStep
        case .finish: finishStep
        }
    }

    private var welcomeStep: some View {
        StepLayout(
            icon: "waveform",
            iconTint: nil,
            title: "Speak. It's already typed.",
            subtitle: "Fast, private dictation that runs entirely on your Mac — in any app, without cloud latency or a subscription."
        ) {
            HStack(spacing: DS.Spacing.xl) {
                highlight("bolt.fill", "Under a second", "On-device inference")
                highlight("lock.fill", "Nothing uploaded", "No cloud, no account")
                highlight("app.badge", "Works everywhere", "Any macOS text field")
            }
            .padding(.top, DS.Spacing.s)
        }
    }

    private var privacyStep: some View {
        StepLayout(
            icon: "lock.shield.fill",
            iconTint: DS.Palette.success,
            title: "Private by design",
            subtitle: "Your voice never leaves this Mac."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                privacyPoint("Speech recognition runs locally on the Neural Engine")
                privacyPoint("Text cleanup runs locally too")
                privacyPoint("No cloud APIs, no audio uploads, no telemetry")
                privacyPoint("No account and no login, ever")
            }
        }
    }

    private var microphoneStep: some View {
        StepLayout(
            icon: micManager.isGranted ? "mic.fill" : "mic.badge.xmark",
            iconTint: micManager.isGranted ? DS.Palette.success : nil,
            title: "Microphone access",
            subtitle: "Needed to hear you. Audio is processed on this Mac and discarded right after transcription."
        ) {
            if micManager.isGranted {
                StatusChip("GRANTED", kind: .positive, systemImage: "checkmark")
            } else {
                Button("Allow Microphone") {
                    Task { _ = await micManager.requestPermission() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var accessibilityStep: some View {
        StepLayout(
            icon: axManager.isTrusted ? "hand.point.up.braille.fill" : "hand.point.up.fill",
            iconTint: axManager.isTrusted ? DS.Palette.success : nil,
            title: "Accessibility access",
            subtitle: "Needed to type your words into Safari, Slack, Notes, VS Code and everywhere else."
        ) {
            VStack(spacing: DS.Spacing.m) {
                if axManager.isTrusted {
                    StatusChip("GRANTED", kind: .positive, systemImage: "checkmark")
                } else {
                    Button("Open System Settings") {
                        axManager.promptForAccessibility()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Enable \(AppConstants.appName) under Privacy & Security › Accessibility. This screen continues by itself once you do.")
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var shortcutStep: some View {
        StepLayout(
            icon: "command",
            iconTint: nil,
            title: "Pick your shortcut",
            subtitle: "This is how you start talking from anywhere on macOS."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                ForEach(ShortcutMode.allCases, id: \.self) { mode in
                    Button {
                        settingsManager.settings.shortcutMode = mode
                    } label: {
                        HStack(spacing: DS.Spacing.m) {
                            Image(systemName: settingsManager.settings.shortcutMode == mode ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(settingsManager.settings.shortcutMode == mode ? Color.accentColor : Color.secondary)

                            Text(mode.displayName)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)

                            KeycapView(shortcut: mode)

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text(settingsManager.settings.shortcutMode.summary)
                    .font(DS.Font.rowDetail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DS.Spacing.xs)
            }
        }
    }

    private var modelStep: some View {
        let tier = settingsManager.settings.speechModelTier
        return StepLayout(
            icon: "arrow.down.circle.fill",
            iconTint: nil,
            title: "Download the speech model",
            subtitle: "\(tier.displayName) (\(tier.sizeLabel)) — \(tier.description)"
        ) {
            if modelManager.isModelDownloaded(tier: tier) {
                StatusChip("INSTALLED", kind: .positive, systemImage: "checkmark")
            } else if modelManager.activeDownloadId == tier.modelId {
                VStack(spacing: DS.Spacing.s) {
                    ProgressView(value: modelManager.currentDownloadProgress)
                        .frame(width: 300)
                    Text(modelManager.currentDownloadStatus)
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Download \(tier.displayName) Model") {
                    modelManager.downloadModel(tier: tier)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var testStep: some View {
        StepLayout(
            icon: "sparkles",
            iconTint: nil,
            title: "Give it a try",
            subtitle: "Hold \(settingsManager.settings.shortcutMode.displayName) — or press the button — and say something."
        ) {
            VStack(spacing: DS.Spacing.m) {
                Button {
                    if appState.dictationState == .listening {
                        appState.stopListeningAndProcess()
                    } else {
                        appState.startListening()
                    }
                } label: {
                    Label(
                        appState.dictationState == .listening ? "Stop & Transcribe" : "Start Speaking",
                        systemImage: appState.dictationState == .listening ? "stop.fill" : "mic.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(appState.dictationState == .listening ? DS.Palette.recording : .accentColor)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $testInputText)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .padding(DS.Spacing.s)
                        .frame(width: 420, height: 96)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )

                    if testInputText.isEmpty {
                        Text("Your words will appear here…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .padding(.horizontal, DS.Spacing.m)
                            .padding(.vertical, DS.Spacing.m + 2)
                            .allowsHitTesting(false)
                    }
                }
            }
            .onReceive(appState.$lastTranscribedText) { newText in
                if !newText.isEmpty { testInputText = newText }
            }
        }
    }

    private var finishStep: some View {
        StepLayout(
            icon: "checkmark.seal.fill",
            iconTint: DS.Palette.success,
            title: "You're all set",
            subtitle: "\(AppConstants.appName) now lives in your menu bar."
        ) {
            VStack(spacing: DS.Spacing.m) {
                HStack(spacing: DS.Spacing.s) {
                    Text("Press")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    KeycapView(shortcut: settingsManager.settings.shortcutMode)
                    Text("anywhere to dictate.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Text("Press esc while recording to throw a dictation away.")
                    .font(DS.Font.rowDetail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pieces

    private func privacyPoint(_ text: String) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.success)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func highlight(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

/// Shared layout for every onboarding step: hero icon, title, subtitle, content.
private struct StepLayout<Content: View>: View {
    let icon: String
    let iconTint: Color?
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            Group {
                if let iconTint {
                    Image(systemName: icon)
                        .font(.system(size: 52))
                        .foregroundStyle(iconTint)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 52))
                        .foregroundStyle(DS.Palette.waveform)
                }
            }
            .frame(height: 58)

            VStack(spacing: DS.Spacing.s) {
                Text(title)
                    .font(.system(size: 23, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
    }
}
