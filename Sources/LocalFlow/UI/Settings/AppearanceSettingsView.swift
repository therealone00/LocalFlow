import SwiftUI

public struct AppearanceSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Theme & Style").font(.headline)) {
                Picker("Theme", selection: $settingsManager.settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                
                Picker("Floating Bar Size", selection: $settingsManager.settings.floatingBarSize) {
                    ForEach(FloatingBarSize.allCases, id: \.self) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                
                Picker("Floating Bar Position", selection: $settingsManager.settings.floatingBarPosition) {
                    ForEach(FloatingBarPosition.allCases, id: \.self) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }
            }
            
            Section(header: Text("Visual Feedback").font(.headline)) {
                Toggle("Show live transcription under waveform", isOn: $settingsManager.settings.showLiveTranscript)
                
                Toggle("Reduce animations (Optimize for efficiency)", isOn: $settingsManager.settings.reduceMotion)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
