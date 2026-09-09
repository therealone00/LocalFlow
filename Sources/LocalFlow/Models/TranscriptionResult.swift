import Foundation

/// Engine type enumeration.
public enum TranscriptionEngineType: String, Codable, CaseIterable, Sendable {
    case auto = "Auto"
    case whisperKit = "WhisperKit (CoreML)"
    case whisperCpp = "whisper.cpp (Fallback)"
}

/// Standardized output from any speech recognition engine.
public struct TranscriptionResult: Sendable {
    public let text: String
    public let language: String?
    public let duration: TimeInterval
    public let confidence: Float?
    public let segments: [DictationSegment]
    
    public init(
        text: String,
        language: String? = nil,
        duration: TimeInterval = 0,
        confidence: Float? = nil,
        segments: [DictationSegment] = []
    ) {
        self.text = text
        self.language = language
        self.duration = duration
        self.confidence = confidence
        self.segments = segments
    }
}

public struct DictationSegment: Sendable {
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
    
    public init(text: String, start: TimeInterval, end: TimeInterval) {
        self.text = text
        self.start = start
        self.end = end
    }
}
