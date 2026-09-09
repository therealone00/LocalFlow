import Foundation

/// Voice Activity Detector (VAD) for detecting speech onset and silence timeouts.
public final class VoiceActivityDetector: @unchecked Sendable {
    private var silenceStartTime: Date?
    private var isSpeechDetected = false
    private let energyThreshold: Float
    private let lock = NSLock()
    
    public init(energyThreshold: Float = 0.03) {
        self.energyThreshold = energyThreshold
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        silenceStartTime = nil
        isSpeechDetected = false
    }
    
    /// Processes a new audio level and checks if silence duration exceeds the threshold.
    /// Returns true if speech has occurred and subsequent silence exceeded `maxSilenceDuration`.
    public func processLevel(_ level: Float, maxSilenceDuration: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let isSpeaking = level >= energyThreshold
        
        if isSpeaking {
            isSpeechDetected = true
            silenceStartTime = nil
            return false
        }
        
        guard isSpeechDetected else {
            return false
        }
        
        if silenceStartTime == nil {
            silenceStartTime = Date()
            return false
        }
        
        if let start = silenceStartTime, Date().timeIntervalSince(start) >= maxSilenceDuration {
            return true
        }
        
        return false
    }
}
