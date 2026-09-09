import Foundation

/// Engine powered by whisper.cpp for Intel Macs (x86_64) or universal fallback.
public actor WhisperCppEngine: TranscriptionEngine {
    public nonisolated let engineType: TranscriptionEngineType = .whisperCpp
    
    private let modelTier: SpeechModelTier
    private var isCancelled = false
    private var prepared = false
    
    public var isPrepared: Bool {
        prepared
    }
    
    public init(modelTier: SpeechModelTier = .base) {
        self.modelTier = modelTier
    }
    
    public func prepare() async throws {
        prepared = true
        AppLogger.transcription.info("whisper.cpp engine prepared.")
    }
    
    public func transcribe(audioSamples: [Float], language: String?) async throws -> TranscriptionResult {
        if isCancelled {
            throw CancellationError()
        }
        
        guard !audioSamples.isEmpty else {
            return TranscriptionResult(text: "", language: language, duration: 0)
        }
        
        let startTime = Date()
        
        // Write audio to temporary 16kHz mono WAV
        let tempWavURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer {
            try? FileManager.default.removeItem(at: tempWavURL)
        }
        
        try writeWavFile(samples: audioSamples, to: tempWavURL)
        
        // Locate whisper-cpp or whisper-cli
        let possibleBinaries = [
            "/opt/homebrew/bin/whisper-cli",
            "/opt/homebrew/bin/whisper-cpp",
            "/usr/local/bin/whisper-cli",
            "/usr/local/bin/whisper-cpp"
        ]
        
        var whisperBin: String? = nil
        for bin in possibleBinaries {
            if FileManager.default.isExecutableFile(atPath: bin) {
                whisperBin = bin
                break
            }
        }
        
        guard let binaryPath = whisperBin else {
            throw NSError(
                domain: "LocalFlow.WhisperCppEngine",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "whisper.cpp binary not found. Install via 'brew install whisper-cpp' or select WhisperKit on Apple Silicon."]
            )
        }
        
        let modelPath = AppConstants.whisperCppModelsDirectory.appendingPathComponent("ggml-\(modelTier.displayName.lowercased()).bin").path
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        
        var arguments = ["-m", modelPath, "-f", tempWavURL.path, "--no-timestamps"]
        if let lang = language, lang != "auto" {
            arguments.append(contentsOf: ["-l", lang])
        }
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Suppress stderr
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let rawOutput = String(data: data, encoding: .utf8) ?? ""
        let cleanedText = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let duration = Date().timeIntervalSince(startTime)
        
        return TranscriptionResult(
            text: cleanedText,
            language: language,
            duration: duration
        )
    }
    
    public func cancel() {
        isCancelled = true
    }
    
    public func unload() {
        prepared = false
        isCancelled = false
    }
    
    private func writeWavFile(samples: [Float], to url: URL) throws {
        var header = [UInt8]()
        let sampleRate: UInt32 = 16000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate: UInt32 = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign: UInt16 = numChannels * (bitsPerSample / 8)
        let pcmDataSize = UInt32(samples.count * 2)
        let totalChunkSize = 36 + pcmDataSize
        
        // RIFF chunk
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: totalChunkSize.littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)
        
        // fmt chunk
        header.append(contentsOf: "fmt ".utf8)
        let subchunk1Size: UInt32 = 16
        header.append(contentsOf: withUnsafeBytes(of: subchunk1Size.littleEndian) { Array($0) })
        let audioFormat: UInt16 = 1 // PCM
        header.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data chunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: pcmDataSize.littleEndian) { Array($0) })
        
        var data = Data(header)
        
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * 32767.0)
            data.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }
        
        try data.write(to: url)
    }
}
