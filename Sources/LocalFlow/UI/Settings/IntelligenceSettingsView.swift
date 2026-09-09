import SwiftUI

public struct IntelligenceSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Intelligence Level").font(.headline)) {
                Picker("Mode", selection: $settingsManager.settings.intelligenceTier) {
                    ForEach(IntelligenceTier.allCases, id: \.self) { tier in
                        Text(tier.rawValue).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("Cleanup Features").font(.headline)) {
                Toggle("Remove filler words (äh, ähm, uh, um)", isOn: $settingsManager.settings.removeFillerWords)
                
                Toggle("Resolve self-corrections (e.g. 'morgen, nee Donnerstag')", isOn: $settingsManager.settings.resolveSelfCorrections)
                
                Toggle("Smart punctuation & spoken commands (e.g. 'Punkt', 'neue Zeile')", isOn: $settingsManager.settings.smartPunctuation)
                
                Toggle("Smart list formatting (e.g. 'erstens ... zweitens ...')", isOn: $settingsManager.settings.smartFormatting)
            }
            
            Section(header: Text("Context Awareness").font(.headline)) {
                Toggle("Adapt style by application (Mail, Chat, Code, Docs)", isOn: $settingsManager.settings.useAppContext)
                
                Toggle("Use local cursor context (maintains case and flow)", isOn: $settingsManager.settings.useCursorContext)
                
                Text("Cursor context is never stored and never read in secure or password fields.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
