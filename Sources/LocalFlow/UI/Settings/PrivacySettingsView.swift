import SwiftUI

public struct PrivacySettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var historyManager = HistoryManager.shared

    @State private var isConfirmingClear = false

    public init() {}

    public var body: some View {
        SettingsPane(
            title: "Privacy",
            subtitle: "What stays on this Mac — which is everything.",
            systemImage: "lock.shield"
        ) {
            SettingsCard {
                HStack(alignment: .top, spacing: DS.Spacing.l) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(DS.Palette.success)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Everything runs on-device")
                            .font(.system(size: 15, weight: .semibold))

                        Text("No audio, transcript or usage data ever leaves your Mac. There is no cloud service, no external AI API, no account and no telemetry.")
                            .font(DS.Font.rowDetail)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            SettingsCard("Data Retention") {
                SettingRow(
                    "Audio recordings",
                    detail: "Audio only ever exists in memory during transcription and is discarded immediately after."
                ) {
                    StatusChip("NEVER SAVED", kind: .positive, systemImage: "checkmark")
                }

                SettingToggle(
                    "Keep dictation history",
                    detail: "Stores the last 100 transcripts locally so you can re-insert them. Turn this off to keep nothing at all.",
                    isOn: $settingsManager.settings.saveDictationHistory
                )

                SettingRow("Stored transcripts") {
                    HStack(spacing: DS.Spacing.m) {
                        Text("\(historyManager.items.count)")
                            .font(DS.Font.rowTitle)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                        Button("Clear…", role: .destructive) {
                            isConfirmingClear = true
                        }
                        .controlSize(.small)
                        .disabled(historyManager.items.isEmpty)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete all \(historyManager.items.count) stored transcripts?",
            isPresented: $isConfirmingClear
        ) {
            Button("Delete History", role: .destructive) {
                historyManager.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}
