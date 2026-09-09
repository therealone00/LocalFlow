import XCTest
@testable import LocalFlow

final class VoiceActivityDetectorTests: XCTestCase {
    func testSilenceDetection() {
        let vad = VoiceActivityDetector(energyThreshold: 0.05)
        
        // Initial silence before speech should not trigger auto-stop
        XCTAssertFalse(vad.processLevel(0.01, maxSilenceDuration: 0.1))
        
        // Speech onset
        XCTAssertFalse(vad.processLevel(0.2, maxSilenceDuration: 0.1))
        
        // Immediate silence after speech should not immediately trigger
        XCTAssertFalse(vad.processLevel(0.01, maxSilenceDuration: 0.1))
        
        // Wait for silence duration to elapse
        Thread.sleep(forTimeInterval: 0.15)
        
        // Next silence frame should trigger auto-stop
        XCTAssertTrue(vad.processLevel(0.01, maxSilenceDuration: 0.1))
    }
}
