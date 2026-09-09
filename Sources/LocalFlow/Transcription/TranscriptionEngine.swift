import Foundation

/// Abstract protocol for local speech-to-text engines using Swift Concurrency Actors.
public protocol TranscriptionEngine: Actor {
    var engineType: TranscriptionEngineType { get }
    var isPrepared: Bool { get }
    
    /// Prewarms and compiles/loads the model into memory.
    func prepare() async throws
    
    /// Transcribes an array of 16kHz mono Float32 audio samples.
    func transcribe(audioSamples: [Float], language: String?) async throws -> TranscriptionResult
    
    /// Cancels any active inference task.
    func cancel() async
    
    /// Unloads the model from memory to conserve system RAM.
    func unload() async
}
