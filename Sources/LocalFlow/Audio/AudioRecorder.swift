import Foundation
@preconcurrency import AVFoundation
import Accelerate

/// Thread-safe sample storage actor.
public actor AudioBufferStore {
    private var samples: [Float] = []
    
    public init() {
        samples.reserveCapacity(16000 * 30) // Pre-allocate 30 seconds
    }
    
    public func append(_ newSamples: [Float]) {
        samples.append(contentsOf: newSamples)
    }
    
    public func retrieveAndClear() -> [Float] {
        let result = samples
        samples.removeAll(keepingCapacity: true)
        return result
    }
    
    public func clear() {
        samples.removeAll(keepingCapacity: true)
    }
    
    public var count: Int {
        samples.count
    }
}

/// High-performance audio recorder optimized for low-latency dictation.
public final class AudioRecorder: @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private let bufferStore = AudioBufferStore()
    
    public var onLevelUpdate: (@Sendable (Float) -> Void)?
    public var onVoiceActivity: (@Sendable (Bool) -> Void)?
    
    private let targetSampleRate: Double = 16000.0
    private let targetChannelCount: AVAudioChannelCount = 1
    
    private var isRecordingInternal = false
    private let queue = DispatchQueue(label: "com.localflow.audiorecorder")
    
    public var isRecording: Bool {
        queue.sync { isRecordingInternal }
    }
    
    public init() {}
    
    /// Starts capturing microphone audio.
    public func startRecording(deviceUID: String? = nil) throws {
        var shouldProceed = false
        queue.sync {
            if !isRecordingInternal {
                isRecordingInternal = true
                shouldProceed = true
            }
        }
        
        guard shouldProceed else { return }
        
        Task {
            await bufferStore.clear()
        }
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        let inputNode = engine.inputNode
        
        let hwFormat = inputNode.inputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0 else {
            queue.sync { isRecordingInternal = false }
            throw NSError(domain: "LocalFlow.AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid hardware input format"])
        }
        
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: targetChannelCount,
            interleaved: false
        ) else {
            queue.sync { isRecordingInternal = false }
            throw NSError(domain: "LocalFlow.AudioRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not create target audio format"])
        }
        
        guard let converter = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            queue.sync { isRecordingInternal = false }
            throw NSError(domain: "LocalFlow.AudioRecorder", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not create audio format converter"])
        }
        self.converter = converter
        
        let bufferSize: AVAudioFrameCount = 1024
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hwFormat) { [weak self] (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
            guard let self = self else { return }
            self.processInputBuffer(buffer: buffer, targetFormat: targetFormat)
        }
        
        engine.prepare()
        try engine.start()
        AppLogger.audio.info("Audio recording started successfully.")
    }
    
    /// Stops audio capture and returns 16kHz mono Float32 audio samples.
    public func stopRecording() async -> [Float] {
        var wasRecording = false
        queue.sync {
            if isRecordingInternal {
                isRecordingInternal = false
                wasRecording = true
            }
        }
        
        guard wasRecording else { return [] }
        
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        converter = nil
        
        let samples = await bufferStore.retrieveAndClear()
        AppLogger.audio.info("Audio recording stopped. Captured \(samples.count) samples (\(Double(samples.count) / 16000.0, format: .fixed(precision: 2))s).")
        return samples
    }
    
    /// Cancels audio capture immediately without returning samples.
    public func cancelRecording() {
        queue.sync {
            isRecordingInternal = false
        }
        
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        converter = nil
        
        Task {
            await bufferStore.clear()
        }
        AppLogger.audio.info("Audio recording cancelled.")
    }
    
    private func processInputBuffer(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let converter = self.converter else { return }
        
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 100
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            return
        }
        
        var error: NSError?
        var isConsumed = false
        
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if isConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            isConsumed = true
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            AppLogger.audio.error("Audio conversion error: \(error.localizedDescription)")
            return
        }
        
        guard let channelData = convertedBuffer.floatChannelData else { return }
        let channel = channelData[0]
        let frameCount = Int(convertedBuffer.frameLength)
        guard frameCount > 0 else { return }
        
        let samples = Array(UnsafeBufferPointer(start: channel, count: frameCount))
        
        // Calculate RMS audio level
        var rms: Float = 0
        vDSP_rmsqv(channel, 1, &rms, vDSP_Length(frameCount))
        
        // Normalize RMS to a smooth 0.0 ... 1.0 range
        let normalizedLevel = min(max((rms - 0.005) * 4.0, 0.0), 1.0)
        self.onLevelUpdate?(normalizedLevel)
        
        Task {
            await bufferStore.append(samples)
        }
    }
}
