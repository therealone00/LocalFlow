import Foundation

public actor TranscriptionCoordinator {
    public static let shared = TranscriptionCoordinator()
    
    private var activeEngine: TranscriptionEngine?
    private var activeTier: SpeechModelTier?
    private var activeType: TranscriptionEngineType?
    
    public init() {}
    
    public func getEngine(settings: LocalFlowSettings) async throws -> TranscriptionEngine {
        let requestedType = settings.transcriptionEngine
        let requestedTier = settings.speechModelTier
        
        let resolvedType: TranscriptionEngineType
        if requestedType == .auto {
#if arch(arm64)
            resolvedType = .whisperKit
#else
            resolvedType = .whisperCpp
#endif
        } else {
            resolvedType = requestedType
        }
        
        if let engine = activeEngine, activeTier == requestedTier, activeType == resolvedType {
            let prepared = await engine.isPrepared
            if !prepared {
                try await engine.prepare()
            }
            return engine
        }
        
        // Create new engine
        let newEngine: TranscriptionEngine
        switch resolvedType {
        case .whisperKit, .auto:
            newEngine = WhisperKitEngine(modelTier: requestedTier)
        case .whisperCpp:
            newEngine = WhisperCppEngine(modelTier: requestedTier)
        }
        
        try await newEngine.prepare()
        
        self.activeEngine = newEngine
        self.activeTier = requestedTier
        self.activeType = resolvedType
        
        return newEngine
    }
    
    public func transcribe(samples: [Float], settings: LocalFlowSettings) async throws -> TranscriptionResult {
        let engine = try await getEngine(settings: settings)
        let language = settings.language == "auto" ? nil : settings.language
        return try await engine.transcribe(audioSamples: samples, language: language)
    }
    
    public func cancel() async {
        await activeEngine?.cancel()
    }
    
    public func unload() async {
        await activeEngine?.unload()
        activeEngine = nil
        activeTier = nil
        activeType = nil
    }
}
