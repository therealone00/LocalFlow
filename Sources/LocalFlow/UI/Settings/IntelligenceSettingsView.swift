import SwiftUI

public struct IntelligenceSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared

    public init() {}

    private var tier: IntelligenceTier { settingsManager.settings.intelligenceTier }

    public var body: some View {
        SettingsPane(
            title: "Intelligence",
            subtitle: "How much \(AppConstants.appName) cleans up what you said before inserting it.",
            systemImage: "sparkles"
        ) {
            SettingsCard("Cleanup Level", footnote: tier.summary) {
                Picker("", selection: $settingsManager.settings.intelligenceTier) {
                    ForEach(IntelligenceTier.allCases, id: \.self) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            SettingsCard("Cleanup Rules") {
                SettingToggle(
                    "Remove filler words",
                    detail: "Drops “äh”, “ähm”, “uh” and “um” without touching the rest of the sentence.",
                    isOn: $settingsManager.settings.removeFillerWords
                )

                SettingToggle(
                    "Resolve self-corrections",
                    detail: "“Tuesday, no, Thursday” becomes “Thursday”.",
                    isOn: $settingsManager.settings.resolveSelfCorrections
                )

                SettingToggle(
                    "Smart punctuation",
                    detail: "Adds punctuation, and understands spoken commands like “Punkt” or “new line”.",
                    isOn: $settingsManager.settings.smartPunctuation
                )

                SettingToggle(
                    "Smart list formatting",
                    detail: "Turns “first … second … third …” into a formatted list.",
                    isOn: $settingsManager.settings.smartFormatting
                )
            }

            SettingsCard(
                "Context",
                footnote: "Cursor context is never stored and is never read from secure or password fields."
            ) {
                SettingToggle(
                    "Adapt to the app you are in",
                    detail: "Writes more formally in Mail, more casually in chat, and code-aware in editors.",
                    isOn: $settingsManager.settings.useAppContext
                )

                SettingToggle(
                    "Use text around the cursor",
                    detail: "Matches capitalisation and continues the sentence you already started.",
                    isOn: $settingsManager.settings.useCursorContext
                )
            }
        }
    }
}
