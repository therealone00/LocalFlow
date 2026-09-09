import SwiftUI

public struct FloatingBarView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var settingsManager = SettingsManager.shared
    
    @State private var pulseRecordDot = false
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 12) {
            switch appState.dictationState {
            case .idle:
                EmptyView()
                
            case .preparing:
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text("Bereite vor…")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                
            case .listening:
                listeningView
                
            case .processing(let stage):
                processingView(stage: stage)
                
            case .success:
                successView
                
            case .error(let message):
                errorView(message: message)
                
            case .cancelled:
                cancelledView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // True macOS frosted glass
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Deep obsidian tint
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.65),
                                Color(red: 0.07, green: 0.07, blue: 0.10).opacity(0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Delicate hairline inner border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.30),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 25, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: appState.dictationState)
    }
    
    // MARK: - Subviews
    
    private var listeningView: some View {
        HStack(spacing: 10) {
            // Pulsing live recording dot
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 18, height: 18)
                    .scaleEffect(pulseRecordDot ? 1.4 : 1.0)
                    .opacity(pulseRecordDot ? 0.0 : 0.8)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color(red: 1.0, green: 0.2, blue: 0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.red.opacity(0.8), radius: 4)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    pulseRecordDot = true
                }
            }
            
            // 7-bar dynamic audio equalizer
            AudioWaveformView(level: appState.audioLevel, isProcessing: false)
            
            // Target app information & mode
            HStack(spacing: 6) {
                if let icon = appState.activeAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                
                Text(appState.activeAppName.isEmpty ? "Diktat" : appState.activeAppName)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if appState.isHandsFreeActive {
                    Text("Freisprechen")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.1, green: 0.85, blue: 1.0))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            
            Spacer(minLength: 4)
            
            // Interactive Quick Buttons
            HStack(spacing: 6) {
                Button {
                    appState.stopListeningAndProcess()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                }
                .buttonStyle(.plain)
                .help("Diktat beenden und einfügen")
                
                Button {
                    appState.cancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Abbrechen (Esc)")
            }
        }
    }
    
    private func processingView(stage: DictationState.ProcessingStage) -> some View {
        HStack(spacing: 12) {
            AudioWaveformView(level: 0.6, isProcessing: true)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(stageTitle(stage))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Lokale Neural Engine")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    private var successView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(red: 0.2, green: 0.88, blue: 0.45))
                .shadow(color: Color.green.opacity(0.4), radius: 6)
            
            Text("Eingefügt")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private func errorView(message: String) -> some View {
        let isAccessibility = message.localizedCaseInsensitiveContains("Bedienungshilfen") ||
                              message.localizedCaseInsensitiveContains("Accessibility") ||
                              message.localizedCaseInsensitiveContains("Clipboard")
        
        return HStack(spacing: 10) {
            if isAccessibility {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Bedienungshilfen erforderlich")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Erlaube LocalFlow, Text einzutippen")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
                }
                
                Button {
                    AccessibilityManager.shared.openSystemSettings()
                } label: {
                    Text("Aktivieren ➔")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.yellow)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.orange)
                
                Text(message)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var cancelledView: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
            Text("Abgebrochen")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private func stageTitle(_ stage: DictationState.ProcessingStage) -> String {
        switch stage {
        case .transcribing: return "Transkribiere lokal…"
        case .polishing: return "Optimiere Text…"
        case .inserting: return "Füge ein…"
        }
    }
}
