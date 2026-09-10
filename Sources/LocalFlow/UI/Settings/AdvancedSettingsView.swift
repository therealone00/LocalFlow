import SwiftUI
import AppKit

public struct AdvancedSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared

    @State private var isConfirmingReset = false

    public init() {}

    public var body: some View {
        SettingsPane(
            title: "Advanced",
            subtitle: "Engine internals, file locations and recovery.",
            systemImage: "slider.horizontal.3"
        ) {
            SettingsCard("Engine") {
                SettingRow(
                    "Transcription backend",
                    detail: "Auto picks WhisperKit on Apple Silicon and falls back to whisper.cpp elsewhere."
                ) {
                    Picker("", selection: $settingsManager.settings.transcriptionEngine) {
                        ForEach(TranscriptionEngineType.allCases, id: \.self) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                    .frame(width: 200)
                }

                SettingRow(
                    "Model residency",
                    detail: settingsManager.settings.prewarmPolicy.summary
                ) {
                    Picker("", selection: $settingsManager.settings.prewarmPolicy) {
                        ForEach(ModelPrewarmPolicy.allCases, id: \.self) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .frame(width: 200)
                }
            }

            SettingsCard("Files") {
                SettingRow("Models", detail: AppConstants.modelsDirectory.path) {
                    Button("Reveal") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: AppConstants.modelsDirectory.path)
                    }
                    .controlSize(.small)
                }

                SettingRow("App data", detail: AppConstants.applicationSupportDirectory.path) {
                    Button("Reveal") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: AppConstants.applicationSupportDirectory.path)
                    }
                    .controlSize(.small)
                }
            }

            SettingsCard("Reset") {
                SettingRow(
                    "Restore factory settings",
                    detail: "Resets every preference including your shortcut. Downloaded models, your dictionary and your history are kept."
                ) {
                    Button("Reset…", role: .destructive) {
                        isConfirmingReset = true
                    }
                    .controlSize(.small)
                }
            }
        }
        .confirmationDialog("Reset all settings to their defaults?", isPresented: $isConfirmingReset) {
            Button("Reset Settings", role: .destructive) {
                settingsManager.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your models, dictionary and history are not affected.")
        }
    }
}
