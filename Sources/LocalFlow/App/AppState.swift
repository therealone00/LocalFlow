import Foundation
import SwiftUI
import AppKit

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // Published UI state
    @Published public private(set) var dictationState: DictationState = .idle
    @Published public private(set) var audioLevel: Float = 0.0
    @Published public private(set) var liveTranscript: String = ""
    @Published public private(set) var isHandsFreeActive: Bool = false
    @Published public private(set) var activeAppIcon: NSImage? = nil
    @Published public private(set) var activeAppName: String = ""
    
    private let recorder = AudioRecorder()
    private let vad = VoiceActivityDetector()
    private var currentSession: DictationSession?
    private var dismissTask: Task<Void, Never>?
    
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
        
        // Ensure accessibility is available
        if !AccessibilityManager.shared.isTrusted {
            AccessibilityManager.shared.promptForAccessibility()
            dictationState = .error(message: "Accessibility access required")
            scheduleDismiss(after: 2.5)
            return
        }
        
        dictationState = .preparing
        vad.reset()
        
        // Read context from currently focused element before anything else
        let context = FocusedElementReader.shared.readCurrentContext(
            readPrecedingText: SettingsManager.shared.settings.useCursorContext
        )
        
        self.activeAppName = context.appName ?? "Active App"
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            self.activeAppIcon = frontApp.icon
        }
        
        currentSession = DictationSession(
            targetAppName: context.appName,
            targetBundleId: context.bundleId,
            status: .preparing
        )
        
        do {
            try recorder.startRecording(deviceUID: SettingsManager.shared.settings.selectedAudioDeviceUID)
            dictationState = .listening
            SoundManager.shared.playStartSound()
            AppLogger.app.info("Dictation started for target app: \(context.appName ?? "Unknown", privacy: .public)")
        } catch {
            dictationState = .error(message: "Microphone error")
            scheduleDismiss(after: 2.0)
            AppLogger.audio.error("Failed to start audio recorder: \(error.localizedDescription)")
        }
    }
    
    public func stopListeningAndProcess() {
        guard dictationState == .listening else { return }
        
        SoundManager.shared.playStopSound()
        dictationState = .processing(stage: .transcribing)
        isHandsFreeActive = false
        
        Task {
            let samples = await recorder.stopRecording()
            
            // Check for minimum audio duration (0.15s = 2400 samples at 16kHz)
            guard samples.count >= 2400 else {
                AppLogger.audio.info("Recording too short. Discarding.")
                self.dictationState = .idle
                return
            }
            
            let settings = SettingsManager.shared.settings
            let startTime = Date()
            
            do {
                // Speech-to-Text Transcription
                let transcriptionResult = try await TranscriptionCoordinator.shared.transcribe(
                    samples: samples,
                    settings: settings
                )
                
                let rawText = transcriptionResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawText.isEmpty else {
                    AppLogger.transcription.info("Empty transcription returned.")
                    self.dictationState = .idle
                    return
                }
                
                // Text Intelligence & Cleanup
                self.dictationState = .processing(stage: .polishing)
                let cleanedText = await TextCleanupEngine.shared.process(
                    rawTranscript: rawText,
                    settings: settings,
                    targetBundleId: self.currentSession?.targetBundleId
                )
                
                // Text Insertion into focused app
                self.dictationState = .processing(stage: .inserting)
                let inserted = await TextInsertionEngine.shared.insertText(cleanedText)
                
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
                    
                    self.scheduleDismiss(after: 0.6)
                } else {
                    self.dictationState = .error(message: "Insertion failed")
                    self.scheduleDismiss(after: 1.5)
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
        isHandsFreeActive = false
        dictationState = .cancelled
        AppLogger.app.info("Dictation cancelled by user.")
        scheduleDismiss(after: 0.4)
    }
    
    public func pasteLastDictation() {
        guard let text = HistoryManager.shared.lastDictationText else { return }
        Task {
            _ = await TextInsertionEngine.shared.insertText(text)
        }
    }
    
    private func scheduleDismiss(after delay: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                self.dictationState = .idle
                self.audioLevel = 0.0
                self.liveTranscript = ""
            }
        }
    }
}
