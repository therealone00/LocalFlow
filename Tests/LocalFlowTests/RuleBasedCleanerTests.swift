import XCTest
@testable import LocalFlow

final class RuleBasedCleanerTests: XCTestCase {
    let cleaner = RuleBasedCleaner.shared
    
    func testGermanFillerRemovalAndQuestionInference() {
        let input = "ähm kannst du Peter sagen dass wir uns morgen treffen"
        let output = cleaner.clean(input, language: "de")
        
        XCTAssertFalse(output.contains("ähm"))
        XCTAssertTrue(output.starts(with: "Kannst du"))
        XCTAssertTrue(output.hasSuffix("?"))
    }
    
    func testGermanSelfCorrection() {
        let input = "wir treffen uns morgen nee Donnerstag um drei"
        let output = cleaner.clean(input, language: "de")
        
        XCTAssertFalse(output.contains("morgen"))
        XCTAssertFalse(output.contains("nee"))
        XCTAssertTrue(output.contains("Donnerstag um drei"))
    }
    
    func testComplexSelfCorrectionWithQuestion() {
        let input = "Kannst du mir ähm warte nein kannst du mir bitte erklären wie ein neuronales Netzwerk funktioniert"
        let output = cleaner.clean(input, language: "de")
        
        XCTAssertFalse(output.contains("ähm"))
        XCTAssertFalse(output.contains("warte"))
        XCTAssertFalse(output.contains("nein"))
        XCTAssertTrue(output.contains("bitte erklären, wie ein neuronales Netzwerk funktioniert?"))
    }
    
    func testSpokenPunctuation() {
        let input = "Hallo Peter Komma wie geht es dir Fragezeichen neue Zeile Alles super Punkt"
        let output = cleaner.clean(input, language: "de")
        
        XCTAssertTrue(output.contains("Hallo Peter,"))
        XCTAssertTrue(output.contains("wie geht es dir?"))
        XCTAssertTrue(output.contains("\nAlles super."))
    }
    
    func testSpokenListFormatting() {
        let input = "Meine Aufgaben sind erstens Rechnung schicken zweitens Peter anrufen drittens Präsentation fertig machen"
        let output = cleaner.clean(input, language: "de", formatLists: true)
        
        XCTAssertTrue(output.contains("1. Rechnung schicken"))
        XCTAssertTrue(output.contains("2. Peter anrufen"))
        XCTAssertTrue(output.contains("3. Präsentation fertig machen"))
    }
    
    func testEnglishFillerAndPunctuation() {
        let input = "so um can you send the report comma thanks"
        let output = cleaner.clean(input, language: "en")
        
        XCTAssertFalse(output.contains(" um "))
        XCTAssertTrue(output.contains("report, thanks"))
    }
    
    func testWhisperHallucinationStripping() {
        let music = cleaner.clean("* Musik *", language: "de")
        XCTAssertEqual(music, "")
        
        let bracketMusic = cleaner.clean("[Music] Hello world", language: "en")
        XCTAssertEqual(bracketMusic, "Hello world")
        
        let subtitle = cleaner.clean("Untertitel der Amara.org-Community", language: "de")
        XCTAssertEqual(subtitle, "")
    }
}
