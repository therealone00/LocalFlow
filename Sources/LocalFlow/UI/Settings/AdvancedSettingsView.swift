import SwiftUI
import AppKit

public struct AdvancedSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Transcription Engine").font(.headline)) {
                Picker("Engine", selection: $settingsManager.settings.transcriptionEngine) {
                    ForEach(TranscriptionEngineType.allCases, id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                
                Picker("Model Memory Residency", selection: $settingsManager.settings.prewarmPolicy) {
                    ForEach(ModelPrewarmPolicy.allCases, id: \.self) { policy in
                        Text(policy.rawValue).tag(policy)
                    }
                }
            }
            
            Section(header: Text("Storage & Paths").font(.headline)) {
                HStack {
                    Text("Models Directory")
                    Spacer()
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: AppConstants.modelsDirectory.path)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                HStack {
                    Text("App Data Directory")
                    Spacer()
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: AppConstants.applicationSupportDirectory.path)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Section(header: Text("Danger Zone").font(.headline)) {
                HStack {
                    Text("Reset all settings to factory defaults")
                    Spacer()
                    Button("Reset Settings", role: .destructive) {
                        settingsManager.resetToDefaults()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
