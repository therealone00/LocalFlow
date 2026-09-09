import SwiftUI

public struct GeneralSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var launchManager = LaunchAtLoginManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Startup & Behavior").font(.headline)) {
                Toggle("Launch \(AppConstants.appName) at Login", isOn: Binding(
                    get: { launchManager.isEnabled },
                    set: { newValue in
                        launchManager.setLaunchAtLogin(newValue)
                        settingsManager.settings.launchAtLogin = newValue
                    }
                ))
                
                Toggle("Show Menu Bar Icon", isOn: $settingsManager.settings.showMenuBarIcon)
                
                Toggle("Sound Effects (Pings on start/stop)", isOn: $settingsManager.settings.soundEffectsEnabled)
            }
            
            Section(header: Text("About").font(.headline)) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(AppConstants.appVersion)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Architecture")
                    Spacer()
                    Text(systemArchitecture())
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func systemArchitecture() -> String {
#if arch(arm64)
        return "Apple Silicon (ARM64)"
#else
        return "Intel (x86_64)"
#endif
    }
}
