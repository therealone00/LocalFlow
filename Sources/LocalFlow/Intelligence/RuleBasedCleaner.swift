import Foundation

/// Fast, deterministic, rule-based text cleaner for German and English dictation.
public final class RuleBasedCleaner: Sendable {
    public static let shared = RuleBasedCleaner()
    
    public init() {}
    
    /// Cleans and formats raw transcribed speech.
    public func clean(
        _ text: String,
        language: String? = nil,
        removeFillers: Bool = true,
        resolveCorrections: Bool = true,
        formatPunctuation: Bool = true,
        formatLists: Bool = true
    ) -> String {
        var result = stripHallucinations(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !result.isEmpty else { return "" }
        
        let isGerman = (language == "de" || (language == nil && looksLikeGerman(result)))
        
        // 1. Resolve self-corrections / backtracks
        if resolveCorrections {
            result = resolveSelfCorrections(result, isGerman: isGerman)
        }
        
        // 2. Remove filler words
        if removeFillers {
            result = removeFillerWords(result, isGerman: isGerman)
        }
        
        // 3. Format spoken punctuation and newlines
        if formatPunctuation {
            result = formatSpokenPunctuation(result, isGerman: isGerman)
            if isGerman {
                result = insertGermanSubordinateCommas(result)
            }
        }
        
        // 4. Format spoken lists
        if formatLists {
            result = formatSpokenLists(result, isGerman: isGerman)
        }
        
        // 5. Clean up spacing and capitalization
        result = normalizeSpacingAndPunctuation(result)
        result = normalizeCapitalization(result)
        
        // 6. Final question mark inference if utterance starts with question words
        result = inferQuestionPunctuation(result, isGerman: isGerman)
        
        return result
    }
    
    // MARK: - Hallucination Filtering
    
    public func stripHallucinations(_ text: String) -> String {
        var str = text
        let patterns = [
            "\\*\\s*musik\\s*\\*",
            "\\[musik\\]",
            "\\(musik\\)",
            "\\[music\\]",
            "\\*\\s*music\\s*\\*",
            "\\(music\\)",
            "\\[geräusche\\]",
            "\\[applaus\\]",
            "\\[applause\\]",
            "\\[silence\\]",
            "\\(silence\\)",
            "(?i)untertitel von.*",
            "(?i)untertitel der amara\\.org.*",
            "(?i)subtitles by the amara\\.org.*",
            "(?i)vielen dank für das zuschauen.*",
            "(?i)thank you for watching.*"
        ]
        for pat in patterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (str as NSString).length)
                str = regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: "")
            }
        }
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Self Correction
    
    /// Resolves retracting phrases like:
    /// "Treffen wir uns morgen, nee Donnerstag" -> "Treffen wir uns Donnerstag"
    /// "Kannst du mir ähm warte nein kannst du mir bitte erklären..." -> "Kannst du mir bitte erklären..."
    public func resolveSelfCorrections(_ text: String, isGerman: Bool) -> String {
        var str = text
        
        // Retraction triggers ordered by specificity
        let triggers = isGerman ? [
            "warte mal nein",
            "warte mal",
            "warte nee",
            "warte nein",
            "ach nein",
            "ach nee",
            "ich meine",
            "besser gesagt",
            "oder vielmehr",
            "nein warte",
            "nee warte",
            "warte",
            "nein",
            "nee"
        ] : [
            "scratch that",
            "no wait",
            "or rather",
            "I mean",
            "actually",
            "no"
        ]
        
        for trigger in triggers {
            // Regex to find: [preceding phrase before comma or pause] + trigger + [correction]
            // E.g.: "morgen, nee Donnerstag"
            let pattern = "(?i)(?:,\\s*|\\s+)" + NSRegularExpression.escapedPattern(for: trigger) + "(?:,\\s*|\\s+)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: (str as NSString).length)
                let matches = regex.matches(in: str, options: [], range: range)
                
                // Process from last to first
                for match in matches.reversed() {
                    let matchRange = match.range
                    let beforeMatch = (str as NSString).substring(to: matchRange.location)
                    let afterMatch = (str as NSString).substring(from: matchRange.location + matchRange.length)
                    
                    // Check if beforeMatch has repeated beginning or a phrase to replace
                    // E.g.: "Kannst du mir ... warte nein kannst du mir bitte..." -> drop the earlier partial
                    if let repeatedStart = findRepeatedPrefix(before: beforeMatch, after: afterMatch) {
                        let prefixCutRange = NSRange(location: 0, length: (beforeMatch as NSString).length - repeatedStart.length)
                        let remainingBefore = (beforeMatch as NSString).substring(to: prefixCutRange.length)
                        str = remainingBefore + afterMatch
                    } else {
                        // Check if beforeMatch ends with a single word or short phrase that is being corrected
                        // E.g.: "Treffen wir uns morgen, nee Donnerstag" -> drop "morgen"
                        let wordsBefore = beforeMatch.split(separator: " ")
                        if let lastWord = wordsBefore.last {
                            let cutIndex = beforeMatch.index(beforeMatch.endIndex, offsetBy: -lastWord.count)
                            let prefix = beforeMatch[..<cutIndex].trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
                            str = (prefix.isEmpty ? "" : prefix + " ") + afterMatch
                        } else {
                            str = afterMatch
                        }
                    }
                }
            }
        }
        
        return str
    }
    
    private func findRepeatedPrefix(before: String, after: String) -> NSRange? {
        let cleanBefore = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAfter = after.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let wordsBefore = cleanBefore.split(separator: " ").map { String($0) }
        let wordsAfter = cleanAfter.split(separator: " ").map { String($0) }
        
        // Check for 1 to 4 word prefix overlaps
        for len in (1...min(wordsBefore.count, wordsAfter.count, 5)).reversed() {
            let prefixBefore = wordsBefore.prefix(len).joined(separator: " ").lowercased()
            let prefixAfter = wordsAfter.prefix(len).joined(separator: " ").lowercased()
            if prefixBefore == prefixAfter {
                return NSRange(location: 0, length: cleanBefore.count)
            }
        }
        return nil
    }
    
    // MARK: - Filler Words Removal
    
    public func removeFillerWords(_ text: String, isGerman: Bool) -> String {
        var str = text
        
        // Filler words with word boundaries
        let germanFillers = [
            "\\bäh\\b",
            "\\bähm\\b",
            "\\bhm\\b",
            "\\böh\\b",
            "\\böhm\\b",
            "\\bhmm\\b",
            "\\bääh\\b",
            "\\bäähm\\b",
            "^also,\\s*",
            "^Also,\\s*"
        ]
        
        let englishFillers = [
            "\\buh\\b",
            "\\bum\\b",
            "\\berm\\b",
            "\\buhm\\b",
            "\\bah\\b"
        ]
        
        let fillers = isGerman ? germanFillers : englishFillers
        
        for pattern in fillers {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (str as NSString).length)
                str = regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: "")
            }
        }
        
        return str
    }
    
    // MARK: - Spoken Punctuation
    
    public func formatSpokenPunctuation(_ text: String, isGerman: Bool) -> String {
        var str = text
        
        let punctuationRules: [(pattern: String, replacement: String)] = isGerman ? [
            ("\\s*\\bneuer absatz\\b\\s*", "\n\n"),
            ("\\s*\\bneue zeile\\b\\s*", "\n"),
            ("\\s*\\bpunkt\\b", "."),
            ("\\s*\\bkomma\\b", ","),
            ("\\s*\\bfragezeichen\\b", "?"),
            ("\\s*\\bausrufezeichen\\b", "!"),
            ("\\s*\\bdoppelpunkt\\b", ":"),
            ("\\s*\\bsemikolon\\b", ";"),
            ("\\s*\\bgedankenstrich\\b\\s*", " – "),
            ("\\s*\\bbindestrich\\b\\s*", "-")
        ] : [
            ("\\s*\\bnew paragraph\\b\\s*", "\n\n"),
            ("\\s*\\bnew line\\b\\s*", "\n"),
            ("\\s*\\bperiod\\b", "."),
            ("\\s*\\bfull stop\\b", "."),
            ("\\s*\\bcomma\\b", ","),
            ("\\s*\\bquestion mark\\b", "?"),
            ("\\s*\\bexclamation mark\\b", "!"),
            ("\\s*\\bexclamation point\\b", "!"),
            ("\\s*\\bcolon\\b", ":"),
            ("\\s*\\bsemicolon\\b", ";"),
            ("\\s*\\bhyphen\\b\\s*", "-"),
            ("\\s*\\bdash\\b\\s*", " – ")
        ]
        
        for rule in punctuationRules {
            if let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (str as NSString).length)
                str = regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: rule.replacement)
            }
        }
        
        return str
    }
    
    // MARK: - Spoken Lists
    
    public func formatSpokenLists(_ text: String, isGerman: Bool) -> String {
        var str = text
        
        let listItems = isGerman ? [
            ("(?i)\\berstens\\b:?\\s*", "\n1. "),
            ("(?i)\\bzweitens\\b:?\\s*", "\n2. "),
            ("(?i)\\bdrittens\\b:?\\s*", "\n3. "),
            ("(?i)\\bviertens\\b:?\\s*", "\n4. "),
            ("(?i)\\bfünftens\\b:?\\s*", "\n5. ")
        ] : [
            ("(?i)\\bfirstly\\b:?\\s*|(?i)\\bfirst\\b:?\\s*", "\n1. "),
            ("(?i)\\bsecondly\\b:?\\s*|(?i)\\bsecond\\b:?\\s*", "\n2. "),
            ("(?i)\\bthirdly\\b:?\\s*|(?i)\\bthird\\b:?\\s*", "\n3. "),
            ("(?i)\\bfourthly\\b:?\\s*|(?i)\\bfourth\\b:?\\s*", "\n4. "),
            ("(?i)\\bfifthly\\b:?\\s*|(?i)\\bfifth\\b:?\\s*", "\n5. ")
        ]
        
        // Only format as list if at least two ordinal markers exist
        var matchCount = 0
        for item in listItems {
            if let regex = try? NSRegularExpression(pattern: item.0, options: []) {
                let range = NSRange(location: 0, length: (str as NSString).length)
                if regex.firstMatch(in: str, options: [], range: range) != nil {
                    matchCount += 1
                }
            }
        }
        
        if matchCount >= 2 {
            for item in listItems {
                if let regex = try? NSRegularExpression(pattern: item.0, options: []) {
                    let range = NSRange(location: 0, length: (str as NSString).length)
                    str = regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: item.1)
                }
            }
        }
        
        return str
    }
    
    // MARK: - Spacing & Normalization
    
    public func normalizeSpacingAndPunctuation(_ text: String) -> String {
        var str = text
        
        // Remove spaces before punctuation: " , " -> ", "
        if let regex = try? NSRegularExpression(pattern: "\\s+([.,!?:;])", options: []) {
            let range = NSRange(location: 0, length: (str as NSString).length)
            str = regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: "$1")
        }
        
        // Ensure single space after punctuation if followed by a letter: ",word" -> ", word"
        if let regex = try? NSRegularExpression(pattern: "([.,!?:;])([A-Za-zÄÖÜäöüß])", options: []) {
            let range = NSRange(location: 0, length: (str as NSString).length)
            str = regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: "$1 $2")
        }
        
        // Collapse multiple spaces
        if let regex = try? NSRegularExpression(pattern: "[ \\t]+", options: []) {
            let range = NSRange(location: 0, length: (str as NSString).length)
            str = regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: " ")
        }
        
        // Clean up empty lines / spaces at start of lines
        let lines = str.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        str = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        return str
    }
    
    // MARK: - Capitalization
    
    public func normalizeCapitalization(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        
        var chars = Array(text)
        var capitalizeNext = true
        
        for i in 0..<chars.count {
            let ch = chars[i]
            if capitalizeNext && ch.isLetter {
                chars[i] = Character(ch.uppercased())
                capitalizeNext = false
            } else if ch == "." || ch == "!" || ch == "?" || ch == "\n" {
                capitalizeNext = true
            }
        }
        
        return String(chars)
    }
    
    // MARK: - Question Mark Inference
    
    public func inferQuestionPunctuation(_ text: String, isGerman: Bool) -> String {
        var str = text
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If already ends with punctuation, leave as is
        if trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!") || trimmed.hasSuffix(":") {
            if trimmed.hasSuffix(".") {
                // Check if it should be a question mark instead
                let questionWords = isGerman ?
                    ["kannst", "könntest", "können", "wie", "was", "warum", "weshalb", "wo", "wohin", "woher", "wann", "wer", "welche", "welcher", "welches"] :
                    ["can", "could", "would", "how", "what", "why", "where", "when", "who", "which", "is", "are", "do", "does", "will"]
                
                let firstWord = trimmed.split(separator: " ").first?.lowercased() ?? ""
                if questionWords.contains(firstWord) {
                    str = String(str.dropLast()) + "?"
                }
            }
            return str
        }
        
        let questionWords = isGerman ?
            ["kannst", "könntest", "können", "wie", "was", "warum", "weshalb", "wo", "wohin", "woher", "wann", "wer", "welche", "welcher", "welches"] :
            ["can", "could", "would", "how", "what", "why", "where", "when", "who", "which", "is", "are", "do", "does", "will"]
        
        let firstWord = trimmed.split(separator: " ").first?.lowercased() ?? ""
        if questionWords.contains(firstWord) {
            str += "?"
        } else if trimmed.count > 15 {
            str += "."
        }
        
        return str
    }
    
    // MARK: - German Subordinate Clause Commas
    
    public func insertGermanSubordinateCommas(_ text: String) -> String {
        var str = text
        let conjunctions = ["dass", "ob", "weil", "obwohl", "sodass", "wobei", "wie"]
        for conj in conjunctions {
            let pattern = "([a-zA-ZäöüÄÖÜß]+)\\s+(" + conj + ")\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (str as NSString).length)
                let matches = regex.matches(in: str, options: [], range: range)
                for match in matches.reversed() {
                    let fullRange = match.range
                    let wordRange = match.range(at: 1)
                    let conjRange = match.range(at: 2)
                    let word = (str as NSString).substring(with: wordRange).lowercased()
                    let matchedConj = (str as NSString).substring(with: conjRange)
                    
                    // Skip if word is a preposition or adverb that joins without comma (e.g. "so wie", "genau wie", "ebenso wie")
                    if matchedConj.lowercased() == "wie" && (word == "so" || word == "genau" || word == "ebenso") {
                        continue
                    }
                    
                    // Check if there is already a comma
                    let matchedText = (str as NSString).substring(with: fullRange)
                    if !matchedText.contains(",") {
                        let replacement = (str as NSString).substring(with: wordRange) + ", " + matchedConj
                        str = (str as NSString).replacingCharacters(in: fullRange, with: replacement)
                    }
                }
            }
        }
        return str
    }
    
    private func looksLikeGerman(_ text: String) -> Bool {
        let germanIndicators = [" der ", " die ", " das ", " und ", " ist ", " ein ", " eine ", " ich ", " du ", " wir ", " nicht ", " mit ", " für "]
        let lower = " " + text.lowercased() + " "
        return germanIndicators.contains { lower.contains($0) } || text.contains("ä") || text.contains("ö") || text.contains("ü") || text.contains("ß")
    }
}
