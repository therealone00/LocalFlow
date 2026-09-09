import SwiftUI

public struct DictationSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var deviceManager = AudioDeviceManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Activation & Shortcuts").font(.headline)) {
                Picker("Trigger Mode", selection: $settingsManager.settings.shortcutMode) {
                    ForEach(ShortcutMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                Toggle("Double-press to toggle Hands-Free Mode", isOn: $settingsManager.settings.doubleTapHandsFree)
                
                Text("Push-to-Talk: Hold key down to speak, release to transcribe and insert.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Audio Input").font(.headline)) {
                Picker("Microphone", selection: Binding(
                    get: { settingsManager.settings.selectedAudioDeviceUID ?? "default" },
                    set: { settingsManager.settings.selectedAudioDeviceUID = ($0 == "default" ? nil : $0) }
                )) {
                    ForEach(deviceManager.availableDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                
                HStack {
                    Text("Auto-Stop Silence")
                    Spacer()
                    Slider(
                        value: $settingsManager.settings.autoStopSilenceDuration,
                        in: 1.0...5.0,
                        step: 0.5
                    )
                    .frame(width: 140)
                    Text(String(format: "%.1fs", settingsManager.settings.autoStopSilenceDuration))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            
            Section(header: Text("Language").font(.headline)) {
                Picker("Spoken Language", selection: $settingsManager.settings.language) {
                    Text("Auto Detect (Multilingual)").tag("auto")
                    Text("Deutsch (German)").tag("de")
                    Text("English").tag("en")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
