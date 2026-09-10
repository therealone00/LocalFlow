import SwiftUI

public struct IntelligenceSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var licenseManager = LicenseManager.shared

    public init() {}

    /// What the pipeline will actually use, which is not always what is stored:
    /// a saved Smart preference falls back to Balanced without a license.
    private var tier: IntelligenceTier { settingsManager.effectiveSettings.intelligenceTier }

    public var body: some View {
        SettingsPane(
            title: "Intelligence",
            subtitle: "How much \(AppConstants.appName) cleans up what you said before inserting it.",
            systemImage: "sparkles"
        ) {
            SettingsCard("Cleanup Level", footnote: tier.summary) {
                Picker("", selection: Binding(
                    get: { tier },
                    set: { settingsManager.settings.intelligenceTier = $0 }
                )) {
                    ForEach(IntelligenceTier.allCases, id: \.self) { candidate in
                        if candidate == .smart && !licenseManager.isPro {
                            Text("\(candidate.displayName) · Pro").tag(candidate)
                        } else {
                            Text(candidate.displayName).tag(candidate)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if !licenseManager.isPro {
                    ProUpsellRow(.smartCleanup)
                }
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
                if licenseManager.isPro {
                    SettingToggle(
                        "Adapt to the app you are in",
                        detail: "Writes more formally in Mail, more casually in chat, and code-aware in editors.",
                        isOn: $settingsManager.settings.useAppContext
                    )
                } else {
                    ProUpsellRow(.appContextStyles)
                }

                SettingToggle(
                    "Use text around the cursor",
                    detail: "Matches capitalisation and continues the sentence you already started.",
                    isOn: $settingsManager.settings.useCursorContext
                )
            }
        }
    }
}
