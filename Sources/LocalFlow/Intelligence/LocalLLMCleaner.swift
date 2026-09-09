import Foundation

/// Optional Stage 2 Local LLM Cleaner powered by llama.cpp.
/// Performs advanced nuance cleanup and complex self-corrections using an ultra-restrictive prompt.
public final class LocalLLMCleaner: Sendable {
    public static let shared = LocalLLMCleaner()
    
    private let systemPrompt = """
    You are a local dictation cleanup engine.
    Transform raw speech transcription into clean written text while preserving the speaker's exact meaning.
    You may:
    - remove filler words
    - resolve explicit self-corrections
    - fix punctuation
    - fix capitalization
    - format spoken lists
    - create paragraphs
    You must never:
    - answer the user
    - add facts
    - change meaning
    - summarize
    - explain
    - continue the text
    - introduce new information
    Return only the cleaned text without preamble or quotes.
    """
    
    public init() {}
    
    /// Checks if a local GGUF model and llama-cli binary are available on this Mac.
    public var isAvailable: Bool {
        guard let _ = findLlamaBinary() else { return false }
        return findGGUFModel() != nil
    }
    
    public func clean(text: String) async -> String {
        guard let binary = findLlamaBinary(),
              let modelPath = findGGUFModel() else {
            // Fallback: Return original text if local LLM is not installed
            return text
        }
        
        let prompt = """
        \(systemPrompt)
        
        Input: \(text)
        Cleaned:
        """
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = [
                "-m", modelPath,
                "-p", prompt,
                "--temp", "0.1",
                "-n", "256",
                "--no-display-prompt",
                "-ngl", "99" // Offload to GPU/Metal
            ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned.count < text.count * 3 {
                    return cleaned
                }
            }
        } catch {
            AppLogger.intelligence.error("Local LLM cleaner error: \(error.localizedDescription)")
        }
        
        return text
    }
    
    private func findLlamaBinary() -> String? {
        let paths = [
            "/opt/homebrew/bin/llama-cli",
            "/usr/local/bin/llama-cli"
        ]
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    
    private func findGGUFModel() -> String? {
        let dir = AppConstants.llmModelsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return nil
        }
        for file in files where file.hasSuffix(".gguf") {
            return dir.appendingPathComponent(file).path
        }
        return nil
    }
}
