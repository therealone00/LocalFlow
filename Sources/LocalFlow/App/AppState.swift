import Foundation
import SwiftUI
import AppKit
import AVFoundation

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // Published UI state
    @Published public private(set) var dictationState: DictationState = .idle
    @Published public private(set) var audioLevel: Float = 0.0
    @Published public private(set) var lastTranscribedText: String = ""
    @Published public private(set) var isHandsFreeActive: Bool = false
    @Published public private(set) var activeAppIcon: NSImage? = nil
    @Published public private(set) var activeAppName: String = ""
    /// When the current recording started, or `nil` when not recording.
    /// The floating bar derives its elapsed timer from this.
    @Published public private(set) var recordingStartedAt: Date? = nil
    
    private let recorder = AudioRecorder()
    private let vad = VoiceActivityDetector()
    /// Bundle id of the app the dictation is destined for, used to pick a
    /// writing style during cleanup.
    private var targetBundleId: String?
    private var targetApplication: NSRunningApplication?
    private var dismissTask: Task<Void, Never>?
    
    /// Seconds the microphone has been open for the current session.
    public var recordingDuration: TimeInterval {
        guard let start = recordingStartedAt else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    public init() {
        setupAudioCallbacks()
    }
    
    private func setupAudioCallbacks() {
        recorder.onLevelUpdate = { [weak self] level in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.audioLevel = level
                
                // If in hands-free mode, check VAD for auto-stop
                if self.isHandsFreeActive && self.dictationState == .listening {
                    let maxSilence = SettingsManager.shared.settings.autoStopSilenceDuration
                    if self.vad.processLevel(level, maxSilenceDuration: maxSilence) {
                        AppLogger.audio.info("VAD detected silence limit. Auto-stopping dictation.")
                        self.stopListeningAndProcess()
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    public func handleHotkeyAction(_ action: HotkeyAction) {
        switch action {
        case .pushToTalkDown:
            if dictationState == .idle {
                isHandsFreeActive = false
                startListening()
            }
        case .pushToTalkUp:
            if dictationState == .listening && !isHandsFreeActive {
                stopListeningAndProcess()
            }
        case .toggleHandsFree:
            if dictationState == .listening {
                isHandsFreeActive = false
                stopListeningAndProcess()
            } else if dictationState == .idle {
                isHandsFreeActive = true
                startListening()
            }
        case .cancelSession:
            if dictationState == .listening || isHandsFreeActive {
                cancel()
            }
        case .pasteLastDictation:
            pasteLastDictation()
        }
    }
    
    public func startListening() {
        dismissTask?.cancel()
        
        // Check microphone authorization
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .denied || micStatus == .restricted {
            MicrophoneAccessManager.shared.openSystemSettings()
            dictationState = .error(message: "Microphone access denied")
            scheduleDismiss(after: 2.5)
            return
        }
        
        // Capture target application before dictation UI appears
        var targetApp = NSWorkspace.shared.frontmostApplication
        if targetApp?.bundleIdentifier == Bundle.main.bundleIdentifier {
            targetApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.isActive == false && $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
            })
        }
        self.targetApplication = targetApp
        
        dictationState = .preparing
        vad.reset()
        
        // Read context from currently focused element
        let context = FocusedElementReader.shared.readCurrentContext(
            readPrecedingText: SettingsManager.shared.effectiveSettings.useCursorContext
        )
        
        self.activeAppName = targetApp?.localizedName ?? context.appName ?? "Active App"
        self.activeAppIcon = targetApp?.icon ?? NSWorkspace.shared.frontmostApplication?.icon
        
        self.targetBundleId = targetApp?.bundleIdentifier ?? context.bundleId
        
        do {
            try recorder.startRecording(deviceUID: SettingsManager.shared.effectiveSettings.selectedAudioDeviceUID)
            recordingStartedAt = Date()
            dictationState = .listening
            SoundManager.shared.playStartSound()
            AppLogger.app.info("Dictation started for target app: \(self.activeAppName, privacy: .public)")
        } catch {
            recordingStartedAt = nil
            dictationState = .error(message: "Could not start the microphone")
            scheduleDismiss(after: 2.0)
            AppLogger.audio.error("Failed to start audio recorder: \(error.localizedDescription)")
        }
    }
    
    public func stopListeningAndProcess() {
        guard dictationState == .listening else { return }
        
        SoundManager.shared.playStopSound()
        recordingStartedAt = nil
        dictationState = .processing(stage: .transcribing)
        isHandsFreeActive = false
        GlobalHotkeyManager.shared.resetHandsFreeState()
        
        Task {
            let samples = await recorder.stopRecording()
            
            // Minimum speech duration: 0.15s (2400 samples at 16kHz)
            guard samples.count >= 2400 else {
                AppLogger.audio.info("Recording too short (<0.15s). Discarding.")
                self.dictationState = .idle
                return
            }
            
            let settings = SettingsManager.shared.effectiveSettings
            let startTime = Date()
            
            do {
                // Speech-to-Text Transcription
                let transcriptionResult = try await TranscriptionCoordinator.shared.transcribe(
                    samples: samples,
                    settings: settings
                )
                
                var rawText = transcriptionResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Filter Whisper non-speech hallucinations
                let lower = rawText.lowercased()
                if lower.contains("* musik *") || lower.contains("[musik]") || lower.contains("[music]") ||
                   lower.contains("* music *") || lower.contains("(musik)") || lower.contains("[geräusche]") ||
                   lower.contains("[silence]") || lower == "." || lower == "!" {
                    rawText = ""
                }
                
                guard !rawText.isEmpty else {
                    AppLogger.transcription.info("No speech detected in audio.")
                    self.dictationState = .error(message: "No speech detected")
                    self.scheduleDismiss(after: 1.5)
                    return
                }
                
                // Text Intelligence & Cleanup
                self.dictationState = .processing(stage: .polishing)
                let cleanedText = await TextCleanupEngine.shared.process(
                    rawTranscript: rawText,
                    settings: settings,
                    targetBundleId: self.targetBundleId
                )
                
                self.lastTranscribedText = cleanedText
                
                // Text Insertion into focused app
                self.dictationState = .processing(stage: .inserting)
                let inserted = await TextInsertionEngine.shared.insertText(cleanedText, targetApp: self.targetApplication)
                
                if inserted {
                    SoundManager.shared.playSuccessSound()
                    self.dictationState = .success
                    
                    // Record in local history
                    let duration = Date().timeIntervalSince(startTime)
                    HistoryManager.shared.record(
                        appName: self.activeAppName,
                        text: cleanedText,
                        duration: duration
                    )
                    
                    self.scheduleDismiss(after: 0.8)
                } else {
                    // Accessibility required to type directly into target text field
                        self.dictationState = .error(message: DictationState.accessibilityErrorMessage)
                    self.scheduleDismiss(after: 3.5)
                }
            } catch {
                AppLogger.transcription.error("Transcription pipeline failed: \(error.localizedDescription)")
                self.dictationState = .error(message: error.localizedDescription)
                self.scheduleDismiss(after: 2.0)
            }
        }
    }
    
    public func cancel() {
        recorder.cancelRecording()
        recordingStartedAt = nil
        isHandsFreeActive = false
        GlobalHotkeyManager.shared.resetHandsFreeState()
        dictationState = .cancelled
        AppLogger.app.info("Dictation cancelled by user.")
        scheduleDismiss(after: 0.4)
    }
    
    public func pasteLastDictation() {
        guard let text = HistoryManager.shared.lastDictationText else { return }
        Task {
            _ = await TextInsertionEngine.shared.insertText(text, targetApp: self.targetApplication)
        }
    }
    
    private func scheduleDismiss(after delay: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                self.dictationState = .idle
                self.audioLevel = 0.0
                self.recordingStartedAt = nil
            }
        }
    }
}
