import SwiftUI

public struct AppearanceSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared

    public init() {}

    public var body: some View {
        SettingsPane(
            title: "Appearance",
            subtitle: "How the floating bar looks and where it shows up.",
            systemImage: "paintpalette"
        ) {
            SettingsCard("Floating Bar") {
                FloatingBarPreviewCard(compact: settingsManager.settings.floatingBarSize.isCompact)

                SettingRow("Size", detail: "Compact hides the target app name and shrinks the meter.") {
                    Picker("", selection: $settingsManager.settings.floatingBarSize) {
                        ForEach(FloatingBarSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                SettingRow("Position", detail: "Near Cursor keeps the bar next to where you are typing.") {
                    Picker("", selection: $settingsManager.settings.floatingBarPosition) {
                        ForEach(FloatingBarPosition.allCases, id: \.self) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }

                SettingToggle(
                    "Show transcript preview",
                    detail: "After inserting, the bar briefly shows the first words it typed.",
                    isOn: $settingsManager.settings.showLiveTranscript
                )
            }

            SettingsCard(
                "Theme & Motion",
                footnote: "Reduced motion is also honoured automatically when it is enabled in System Settings › Accessibility."
            ) {
                SettingRow("Theme", detail: "Applies to Settings and Onboarding. The floating bar always stays dark.") {
                    Picker("", selection: $settingsManager.settings.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                SettingToggle(
                    "Reduce motion",
                    detail: "Stops the pulsing indicator and animated meter. Uses less energy.",
                    isOn: $settingsManager.settings.reduceMotion
                )
            }
        }
    }
}

/// Static rendering of the floating bar so size changes can be judged without
/// starting a dictation. It mirrors the real bar's chrome and tokens.
private struct FloatingBarPreviewCard: View {
    let compact: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            HStack(spacing: compact ? DS.Spacing.s : DS.Spacing.m) {
                Circle()
                    .fill(DS.Palette.recording)
                    .frame(width: 8, height: 8)

                AudioWaveformView(level: 0.7, isProcessing: false, compact: compact)

                Text("0:07")
                    .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))

                if !compact {
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 1, height: 16)

                    Text("Mail")
                        .font(DS.Font.barTitle(compact))
                        .foregroundStyle(.white)
                }

                HStack(spacing: DS.Spacing.s) {
                    previewButton("checkmark", tint: DS.Palette.success, prominent: true)
                    previewButton("xmark", tint: .white.opacity(0.55), prominent: false)
                }
            }
            .padding(.horizontal, compact ? DS.Spacing.m : DS.Spacing.l)
            .padding(.vertical, compact ? DS.Spacing.s : 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                        .fill(Color(red: 0.07, green: 0.07, blue: 0.10).opacity(0.95))
                    RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
                }
            )
            .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
            .animation(DS.Motion.bar, value: compact)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.22), Color.gray.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .accessibilityLabel("Preview of the floating bar")
    }

    private func previewButton(_ symbol: String, tint: Color, prominent: Bool) -> some View {
        ZStack {
            Circle()
                .fill(prominent ? tint.opacity(0.20) : Color.white.opacity(0.08))
                .frame(width: 22, height: 22)
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}
