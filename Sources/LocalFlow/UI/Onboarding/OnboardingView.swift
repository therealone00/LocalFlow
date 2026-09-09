import SwiftUI

public struct OnboardingView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var micManager = MicrophoneAccessManager.shared
    @ObservedObject var axManager = AccessibilityManager.shared
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var appState = AppState.shared
    
    @State private var currentStep: Int = 1
    @State private var testInputText: String = ""
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Group {
                switch currentStep {
                case 1:
                    welcomeScreen
                case 2:
                    privacyScreen
                case 3:
                    microphoneScreen
                case 4:
                    accessibilityScreen
                case 5:
                    shortcutScreen
                case 6:
                    modelScreen
                case 7:
                    testScreen
                case 8:
                    finishScreen
                default:
                    EmptyView()
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            
            Spacer()
            
            // Bottom navigation
            HStack {
                if currentStep > 1 && currentStep < 8 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep < 8 {
                    Button("Continue") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed(step: currentStep))
                } else {
                    Button("Get Started") {
                        settingsManager.settings.hasCompletedOnboarding = true
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 580, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Screens
    
    private var welcomeScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Speak. It's already typed.")
                .font(.system(size: 24, weight: .bold))
            
            Text("Fast, private AI dictation that runs entirely on your Mac.\nDictate in any app without cloud latency or subscription lock-in.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
    }
    
    private var privacyScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Private by Design")
                .font(.system(size: 24, weight: .bold))
            
            Text("Your voice stays strictly on this Mac.")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 10) {
                Label("100% Local speech recognition", systemImage: "checkmark.circle.fill")
                Label("Local text intelligence & cleanup", systemImage: "checkmark.circle.fill")
                Label("Zero cloud APIs, zero audio uploads", systemImage: "checkmark.circle.fill")
                Label("No account or login required", systemImage: "checkmark.circle.fill")
            }
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
    }
    
    private var microphoneScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: micManager.isGranted ? "mic.fill" : "mic.badge.xmark")
                .font(.system(size: 64))
                .foregroundColor(micManager.isGranted ? .green : .accentColor)
            
            Text("Microphone Access")
                .font(.system(size: 24, weight: .bold))
            
            Text("Your microphone audio is processed locally and never leaves this Mac.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Button(micManager.isGranted ? "Access Granted" : "Enable Microphone") {
                Task {
                    _ = await micManager.requestPermission()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(micManager.isGranted)
        }
    }
    
    private var accessibilityScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: axManager.isTrusted ? "hand.point.up.braille.fill" : "hand.point.up.fill")
                .font(.system(size: 64))
                .foregroundColor(axManager.isTrusted ? .green : .accentColor)
            
            Text("Accessibility Access")
                .font(.system(size: 24, weight: .bold))
            
            Text("Required to insert text directly into Safari, Slack, Notes, VS Code, and other apps.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Button(axManager.isTrusted ? "Access Granted" : "Enable Accessibility") {
                axManager.promptForAccessibility()
            }
            .buttonStyle(.borderedProminent)
            .disabled(axManager.isTrusted)
        }
    }
    
    private var shortcutScreen: some View {
        VStack(spacing: 14) {
            Image(systemName: "command")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
            
            Text("Choose Your Dictation Shortcut")
                .font(.system(size: 22, weight: .bold))
            
            Picker("", selection: $settingsManager.settings.shortcutMode) {
                ForEach(ShortcutMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .frame(width: 380)
            
            Text("Tip: Hold Fn / Globe is standard. If your Fn key is set to Emoji/Input source in macOS Settings, select 'Hold Right Option'.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var modelScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Speech Model")
                .font(.system(size: 24, weight: .bold))
            
            Text("Recommended: Whisper Base Multilingual (~140 MB)\nRuns on Apple Neural Engine with low latency and high accuracy for German & English.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            if modelManager.isModelDownloaded(tier: .base) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Model is installed and ready to transcribe.")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .padding(.top, 4)
            } else if modelManager.activeDownloadId == SpeechModelTier.base.modelId {
                VStack(spacing: 8) {
                    ProgressView(value: modelManager.currentDownloadProgress)
                        .frame(width: 280)
                    Text(modelManager.currentDownloadStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Download Whisper Base Model") {
                    modelManager.downloadModel(tier: .base)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var testScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Test \(AppConstants.appName)")
                .font(.system(size: 22, weight: .bold))
            
            Text("Click below or hold your hotkey (\(settingsManager.settings.shortcutMode.rawValue)) to speak:")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button(action: {
                    if appState.dictationState == .listening {
                        appState.stopListeningAndProcess()
                    } else {
                        appState.startListening()
                    }
                }) {
                    HStack {
                        Image(systemName: appState.dictationState == .listening ? "stop.fill" : "mic.fill")
                        Text(appState.dictationState == .listening ? "Stop & Transcribe" : "Click to Speak")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(appState.dictationState == .listening ? .red : .accentColor)
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $testInputText)
                    .frame(width: 400, height: 90)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                
                if testInputText.isEmpty {
                    Text("Your spoken text will appear here automatically…")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .onReceive(appState.$lastTranscribedText) { newText in
                if !newText.isEmpty {
                    testInputText = newText
                }
            }
        }
    }
    
    private var finishScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.system(size: 24, weight: .bold))
            
            Text("\(AppConstants.appName) is now running discreetly in your menu bar.\nPress your hotkey anywhere on macOS to dictate into any text field.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
    }
    
    private func canProceed(step: Int) -> Bool {
        switch step {
        case 3:
            return micManager.isGranted
        case 4:
            return axManager.isTrusted
        default:
            return true
        }
    }
}
