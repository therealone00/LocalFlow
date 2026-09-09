import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var historyManager = HistoryManager.shared
    @ObservedObject var launchManager = LaunchAtLoginManager.shared
    
    public var onOpenSettings: () -> Void
    public var onOpenOnboarding: () -> Void
    
    public init(onOpenSettings: @escaping () -> Void, onOpenOnboarding: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onOpenOnboarding = onOpenOnboarding
    }
    
    public var body: some View {
        VStack {
            // Status item
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text("\(AppConstants.appName): \(statusText)")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.vertical, 4)
            
            Divider()
            
            Button("Start Dictation") {
                appState.startListening()
            }
            .disabled(appState.dictationState != .idle)
            
            Button(appState.isHandsFreeActive ? "Stop Hands-Free" : "Hands-Free Dictation") {
                appState.handleHotkeyAction(.toggleHandsFree)
            }
            
            if !historyManager.items.isEmpty {
                Menu("Recent Dictations") {
                    ForEach(historyManager.items.prefix(5)) { item in
                        Button("\(item.targetAppName): \"\(item.text.prefix(30))…\"") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.text, forType: .string)
                        }
                    }
                }
            }
            
            Button("Paste Last Dictation") {
                appState.pasteLastDictation()
            }
            .disabled(historyManager.lastDictationText == nil)
            
            Divider()
            
            Button("Settings…") {
                onOpenSettings()
            }
            
            Button("Onboarding…") {
                onOpenOnboarding()
            }
            
            Toggle("Launch at Login", isOn: Binding(
                get: { launchManager.isEnabled },
                set: { launchManager.setLaunchAtLogin($0) }
            ))
            
            Divider()
            
            Button("Quit \(AppConstants.appName)") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private var statusText: String {
        switch appState.dictationState {
        case .idle: return "Ready"
        case .preparing: return "Preparing…"
        case .listening: return "Listening…"
        case .processing(let stage): return stage.rawValue
        case .success: return "Done"
        case .error(let msg): return msg
        case .cancelled: return "Cancelled"
        }
    }
    
    private var statusColor: Color {
        switch appState.dictationState {
        case .idle: return .green
        case .preparing, .processing: return .orange
        case .listening: return .red
        case .success: return .green
        case .error: return .red
        case .cancelled: return .gray
        }
    }
}
