import Foundation

/// Represents the stages of a dictation workflow.
public enum DictationState: Equatable, Sendable {
    case idle
    case preparing
    case listening
    case processing(stage: ProcessingStage)
    case success
    case error(message: String)
    case cancelled
    
    public enum ProcessingStage: String, Equatable, Sendable {
        case transcribing = "Transcribing…"
        case polishing = "Polishing…"
        case inserting = "Inserting…"
    }
}

/// Timing and performance metrics for a single dictation session.
public struct PerformanceMetrics: Sendable {
    public var startTime: Date = Date()
    public var recordingDuration: TimeInterval = 0
    public var asrDuration: TimeInterval = 0
    public var cleanupDuration: TimeInterval = 0
    public var insertionDuration: TimeInterval = 0
    public var totalDuration: TimeInterval = 0
    
    public init(
        startTime: Date = Date(),
        recordingDuration: TimeInterval = 0,
        asrDuration: TimeInterval = 0,
        cleanupDuration: TimeInterval = 0,
        insertionDuration: TimeInterval = 0,
        totalDuration: TimeInterval = 0
    ) {
        self.startTime = startTime
        self.recordingDuration = recordingDuration
        self.asrDuration = asrDuration
        self.cleanupDuration = cleanupDuration
        self.insertionDuration = insertionDuration
        self.totalDuration = totalDuration
    }
    
    public var realTimeFactor: Double {
        guard recordingDuration > 0 else { return 0 }
        return asrDuration / recordingDuration
    }
}

/// Represents an active or completed dictation session.
public struct DictationSession: Identifiable, Sendable {
    public let id: UUID
    public let startTime: Date
    public var targetAppName: String?
    public var targetBundleId: String?
    public var targetAppIcon: Data?
    public var language: String?
    public var rawTranscript: String?
    public var cleanedTranscript: String?
    public var metrics: PerformanceMetrics
    public var status: DictationState
    
    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        targetAppName: String? = nil,
        targetBundleId: String? = nil,
        targetAppIcon: Data? = nil,
        language: String? = nil,
        rawTranscript: String? = nil,
        cleanedTranscript: String? = nil,
        metrics: PerformanceMetrics = PerformanceMetrics(),
        status: DictationState = .idle
    ) {
        self.id = id
        self.startTime = startTime
        self.targetAppName = targetAppName
        self.targetBundleId = targetBundleId
        self.targetAppIcon = targetAppIcon
        self.language = language
        self.rawTranscript = rawTranscript
        self.cleanedTranscript = cleanedTranscript
        self.metrics = metrics
        self.status = status
    }
}
