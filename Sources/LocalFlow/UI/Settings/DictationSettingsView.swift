import SwiftUI

public struct DictationSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var deviceManager = AudioDeviceManager.shared

    public init() {}

    private var mode: ShortcutMode { settingsManager.settings.shortcutMode }

    public var body: some View {
        SettingsPane(
            title: "Dictation",
            subtitle: "How you start talking and which microphone is used.",
            systemImage: "mic"
        ) {
            SettingsCard("Shortcut") {
                VStack(alignment: .leading, spacing: DS.Spacing.m) {
                    ForEach(ShortcutMode.allCases, id: \.self) { candidate in
                        ShortcutOptionRow(
                            mode: candidate,
                            isSelected: candidate == mode
                        ) {
                            settingsManager.settings.shortcutMode = candidate
                        }
                    }
                }

                Divider()

                SettingToggle(
                    "Double-press for hands-free",
                    detail: "Tap the shortcut twice to keep recording without holding the key. Recording stops on its own after a pause.",
                    isOn: $settingsManager.settings.doubleTapHandsFree
                )
            }

            SettingsCard("Microphone") {
                SettingRow(
                    "Input device",
                    detail: "System Default follows whatever macOS is using right now."
                ) {
                    Picker("", selection: Binding(
                        get: { settingsManager.settings.selectedAudioDeviceUID ?? "default" },
                        set: { settingsManager.settings.selectedAudioDeviceUID = ($0 == "default" ? nil : $0) }
                    )) {
                        ForEach(deviceManager.availableDevices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .frame(width: 220)
                }

                SettingRow(
                    "Auto-stop after silence",
                    detail: "In hands-free mode, recording ends once you have been quiet this long."
                ) {
                    HStack(spacing: DS.Spacing.s) {
                        Slider(
                            value: $settingsManager.settings.autoStopSilenceDuration,
                            in: 1.0...5.0,
                            step: 0.5
                        )
                        .frame(width: 150)

                        Text(String(format: "%.1f s", settingsManager.settings.autoStopSilenceDuration))
                            .font(DS.Font.rowTitle)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }

            SettingsCard(
                "Language",
                footnote: "Auto-detect handles mixed German and English well, but naming the language improves accuracy on short phrases."
            ) {
                SettingRow("Spoken language") {
                    Picker("", selection: $settingsManager.settings.language) {
                        Text("Auto-detect").tag("auto")
                        Text("Deutsch").tag("de")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
            }
        }
    }
}

/// A selectable shortcut mode showing its keycaps and what it does.
private struct ShortcutOptionRow: View {
    let mode: ShortcutMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.s) {
                        Text(mode.displayName)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(.primary)

                        KeycapView(shortcut: mode)

                        if mode.isPushToTalk {
                            StatusChip("PUSH TO TALK", kind: .neutral)
                        }
                    }

                    Text(mode.summary)
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
