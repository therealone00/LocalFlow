import Foundation

public final class TextCleanupEngine: Sendable {
    public static let shared = TextCleanupEngine()
    
    public init() {}
    
    public func process(
        rawTranscript: String,
        settings: LocalFlowSettings,
        targetBundleId: String? = nil,
        precedingCursorText: String? = nil
    ) async -> String {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let words = trimmed.split(separator: " ")
        
        // Fast path for short affirmations / single words
        if words.count <= 2 {
            let shortCleaned = RuleBasedCleaner.shared.clean(
                trimmed,
                language: settings.language,
                removeFillers: settings.removeFillerWords,
                resolveCorrections: false,
                formatPunctuation: settings.smartPunctuation,
                formatLists: false
            )
            return await MainActor.run {
                DictionaryManager.shared.applyDictionary(to: shortCleaned)
            }
        }
        
        // Stage 1: Rule-based cleanup
        var currentText = RuleBasedCleaner.shared.clean(
            trimmed,
            language: settings.language,
            removeFillers: settings.removeFillerWords,
            resolveCorrections: settings.resolveSelfCorrections,
            formatPunctuation: settings.smartPunctuation,
            formatLists: settings.smartFormatting
        )
        
        // Apply Personal Dictionary
        let textForDictionary = currentText
        currentText = await MainActor.run {
            DictionaryManager.shared.applyDictionary(to: textForDictionary)
        }
        
        // Stage 2: Conditional Local LLM Cleanup
        if settings.intelligenceTier == .smart || (settings.intelligenceTier == .balanced && words.count > 15 && LocalLLMCleaner.shared.isAvailable) {
            currentText = await LocalLLMCleaner.shared.clean(text: currentText)
        }
        
        // Stage 3: Context & Application Styling
        if settings.useAppContext {
            let category = ContextAnalyzer.shared.categorizeApplication(bundleId: targetBundleId)
            let cursorContext = settings.useCursorContext ? precedingCursorText : nil
            currentText = StyleEngine.shared.applyStyle(
                text: currentText,
                category: category,
                precedingCursorText: cursorContext
            )
        }
        
        return currentText
    }
}
