import SwiftUI

public struct PrivacySettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var historyManager = HistoryManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("100% Local Speech Processing")
                            .font(.headline)
                        Text("No audio, transcripts, or personal data ever leave your Mac. No cloud connection, no external AI APIs, and no telemetry.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            
            Section(header: Text("Data Retention").font(.headline)) {
                Toggle("Never save audio recordings", isOn: $settingsManager.settings.neverSaveAudio)
                    .disabled(true) // Always forced on for maximum privacy
                
                Toggle("Save recent dictation text locally", isOn: $settingsManager.settings.saveDictationHistory)
                
                HStack {
                    Text("Stored History Entries")
                    Spacer()
                    Text("\(historyManager.items.count)")
                        .foregroundColor(.secondary)
                    
                    Button("Clear History") {
                        historyManager.clearAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(historyManager.items.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
