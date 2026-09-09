import XCTest
@testable import LocalFlow

final class WhisperKitEngineTests: XCTestCase {
    func testWhisperKitInitializationAndInference() async throws {
        let engine = WhisperKitEngine(modelTier: .base)
        print("Testing WhisperKitEngine prepare()...")
        try await engine.prepare()
        let isReady = await engine.isPrepared
        XCTAssertTrue(isReady)
        
        // Transcribe 1.5 seconds of simulated audio
        let samples = [Float](repeating: 0.0, count: 24000)
        let result = try await engine.transcribe(audioSamples: samples, language: "de")
        print("WhisperKitEngine transcription succeeded! Text: '\(result.text)'")
    }
}
