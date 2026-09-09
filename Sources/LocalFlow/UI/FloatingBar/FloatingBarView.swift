import SwiftUI

public struct FloatingBarView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var settingsManager = SettingsManager.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 10) {
            switch appState.dictationState {
            case .idle:
                EmptyView()
                
            case .preparing:
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text("Readying…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
            case .listening:
                AudioWaveformView(level: appState.audioLevel, isProcessing: false)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(appState.isHandsFreeActive ? "Hands-Free" : "Listening")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if !appState.activeAppName.isEmpty {
                            Text("• \(appState.activeAppName)")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    if settingsManager.settings.showLiveTranscript && !appState.liveTranscript.isEmpty {
                        Text(appState.liveTranscript)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
            case .processing(let stage):
                AudioWaveformView(level: 0.5, isProcessing: true)
                Text(stage.rawValue)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                Text("Done")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text(message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
            case .cancelled:
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Text("Cancelled")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // High-end glass morphism
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: appState.dictationState)
    }
}
