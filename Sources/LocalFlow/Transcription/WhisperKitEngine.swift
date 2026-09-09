import Foundation
import WhisperKit

public actor WhisperKitEngine: TranscriptionEngine {
    public nonisolated let engineType: TranscriptionEngineType = .whisperKit
    
    private var whisperKit: WhisperKit?
    private let modelTier: SpeechModelTier
    private var isCancelled = false
    
    public var isPrepared: Bool {
        whisperKit != nil
    }
    
    public init(modelTier: SpeechModelTier = .base) {
        self.modelTier = modelTier
    }
    
    public func prepare() async throws {
        if whisperKit != nil {
            return
        }
        
        AppLogger.transcription.info("Preparing WhisperKit with model: \(self.modelTier.modelId, privacy: .public)")
        
        let directFolder = AppConstants.whisperKitModelsDirectory
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml")
            .appendingPathComponent(modelTier.modelId)
        
        let config: WhisperKitConfig
        if FileManager.default.fileExists(atPath: directFolder.path) {
            AppLogger.transcription.info("Loading existing local model directly from: \(directFolder.path, privacy: .public)")
            config = WhisperKitConfig(
                modelFolder: directFolder.path,
                verbose: false,
                logLevel: .error
            )
        } else {
            config = WhisperKitConfig(
                model: modelTier.modelId,
                downloadBase: AppConstants.whisperKitModelsDirectory,
                verbose: false,
                logLevel: .error
            )
        }
        
        let kit = try await WhisperKit(config)
        self.whisperKit = kit
        self.isCancelled = false
        
        AppLogger.transcription.info("WhisperKit successfully prepared.")
    }
    
    public func transcribe(audioSamples: [Float], language: String?) async throws -> TranscriptionResult {
        if isCancelled {
            throw CancellationError()
        }
        
        guard let kit = self.whisperKit else {
            throw NSError(domain: "LocalFlow.WhisperKitEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "WhisperKit is not initialized. Call prepare() first."])
        }
        
        let startTime = Date()
        
        // Configure decoding options
        var options = DecodingOptions()
        if let lang = language, lang != "auto" {
            options.language = lang
        }
        options.detectLanguage = (language == nil || language == "auto")
        options.temperature = 0.0
        options.skipSpecialTokens = true
        
        let results = try await kit.transcribe(audioArray: audioSamples, decodeOptions: options)
        
        let duration = Date().timeIntervalSince(startTime)
        
        var combinedText = ""
        var segments: [DictationSegment] = []
        var detectedLanguage: String? = nil
        var averageConfidence: Float = 0.0
        
        if let firstResult = results.first {
            combinedText = firstResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
            detectedLanguage = firstResult.language
            
            for seg in firstResult.segments {
                segments.append(DictationSegment(
                    text: seg.text,
                    start: TimeInterval(seg.start),
                    end: TimeInterval(seg.end)
                ))
            }
            
            if !firstResult.segments.isEmpty {
                var totalProb: Float = 0.0
                for seg in firstResult.segments {
                    totalProb += exp(seg.avgLogprob)
                }
                averageConfidence = totalProb / Float(firstResult.segments.count)
            }
        }
        
        return TranscriptionResult(
            text: combinedText,
            language: detectedLanguage,
            duration: duration,
            confidence: averageConfidence > 0 ? averageConfidence : nil,
            segments: segments
        )
    }
    
    public func cancel() {
        isCancelled = true
    }
    
    public func unload() {
        whisperKit = nil
        isCancelled = false
        AppLogger.transcription.info("WhisperKit unloaded from RAM.")
    }
}
