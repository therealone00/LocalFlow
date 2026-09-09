import XCTest
@testable import LocalFlow

@MainActor
final class DictionaryTests: XCTestCase {
    func testDictionaryReplacements() {
        let manager = DictionaryManager.shared
        manager.addEntry(spokenPhrase: "Swift UI", writtenReplacement: "SwiftUI")
        manager.addEntry(spokenPhrase: "local flow", writtenReplacement: "LocalFlow")
        
        let input1 = "Ich baue eine App mit Swift UI für macOS"
        let output1 = manager.applyDictionary(to: input1)
        XCTAssertEqual(output1, "Ich baue eine App mit SwiftUI für macOS")
        
        let input2 = "Willkommen bei local flow"
        let output2 = manager.applyDictionary(to: input2)
        XCTAssertEqual(output2, "Willkommen bei LocalFlow")
    }
}
