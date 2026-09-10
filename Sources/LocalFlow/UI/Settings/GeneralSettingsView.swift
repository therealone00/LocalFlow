import SwiftUI
import AppKit

public struct GeneralSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var launchManager = LaunchAtLoginManager.shared
    @ObservedObject var micManager = MicrophoneAccessManager.shared
    @ObservedObject var axManager = AccessibilityManager.shared

    public init() {}

    public var body: some View {
        SettingsPane(
            title: "General",
            subtitle: "How \(AppConstants.appName) starts up and behaves on your Mac.",
            systemImage: "gearshape"
        ) {
            SettingsCard(
                "Permissions",
                footnote: "\(AppConstants.appName) cannot record or type without these two permissions."
            ) {
                PermissionRow(
                    title: "Microphone",
                    detail: "Needed to capture your voice. Audio is processed on this Mac only.",
                    systemImage: "mic.fill",
                    isGranted: micManager.isGranted
                ) {
                    Task { _ = await micManager.requestPermission() }
                }

                PermissionRow(
                    title: "Accessibility",
                    detail: "Needed to insert text into the app you are typing in.",
                    systemImage: "hand.raised.fill",
                    isGranted: axManager.isTrusted
                ) {
                    axManager.promptForAccessibility()
                }
            }

            SettingsCard("Startup & Behaviour") {
                SettingToggle(
                    "Launch at login",
                    detail: "Start \(AppConstants.appName) automatically so the hotkey always works.",
                    isOn: Binding(
                        get: { launchManager.isEnabled },
                        set: { newValue in
                            launchManager.setLaunchAtLogin(newValue)
                            settingsManager.settings.launchAtLogin = newValue
                        }
                    )
                )

                SettingToggle(
                    "Show menu bar icon",
                    detail: "Turn this off for a fully invisible app. The hotkey keeps working.",
                    isOn: $settingsManager.settings.showMenuBarIcon
                )

                SettingToggle(
                    "Sound effects",
                    detail: "A short tone when recording starts and stops.",
                    isOn: $settingsManager.settings.soundEffectsEnabled
                )
            }

            SettingsCard("About") {
                SettingRow("Version") {
                    Text(AppConstants.appVersion)
                        .font(DS.Font.rowTitle)
                        .foregroundStyle(.secondary)
                }

                SettingRow("Architecture") {
                    Text(systemArchitecture())
                        .font(DS.Font.rowTitle)
                        .foregroundStyle(.secondary)
                }

                SettingRow("Setup guide", detail: "Walk through permissions, shortcut and model again.") {
                    Button("Open Onboarding…") {
                        AppDelegate.shared?.showOnboarding()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private func systemArchitecture() -> String {
#if arch(arm64)
        return "Apple Silicon"
#else
        return "Intel (x86_64)"
#endif
    }
}
