import Foundation

public final class StyleEngine: Sendable {
    public static let shared = StyleEngine()
    
    public init() {}
    
    /// Applies subtle context-dependent formatting adjustments based on target app category.
    public func applyStyle(
        text: String,
        category: ApplicationCategory,
        precedingCursorText: String?
    ) -> String {
        var result = text
        
        // Context-aware casing: If preceding text does not end in a sentence delimiter, lowercase first character
        if let preceding = precedingCursorText?.trimmingCharacters(in: .whitespaces) {
            if !preceding.isEmpty {
                let lastChar = preceding.last ?? " "
                if lastChar != "." && lastChar != "?" && lastChar != "!" && lastChar != "\n" {
                    if category != .code {
                        // If following a comma or continuing a sentence mid-clause
                        if lastChar == "," || lastChar == ":" || lastChar == ";" {
                            result = lowercaseFirstLetter(result)
                        }
                    }
                }
            }
        }
        
        switch category {
        case .code:
            // For code applications, avoid automatic sentence-ending punctuation if the user didn't speak it
            if result.hasSuffix(".") && !text.lowercased().contains("punkt") && !text.lowercased().contains("period") {
                result = String(result.dropLast())
            }
        case .email:
            // Professional tone
            break
        case .workChat, .personalChat:
            // Concise tone
            break
        case .document, .other:
            break
        }
        
        return result
    }
    
    private func lowercaseFirstLetter(_ str: String) -> String {
        guard let first = str.first else { return str }
        // Keep uppercase if likely an acronym or German noun is unclear, but for standard lowercase continuation:
        return String(first).lowercased() + str.dropFirst()
    }
}
