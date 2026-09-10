import Foundation

/// Centralized configuration and constants for the application.
/// Allows trivial rebranding (e.g. changing the app name) across the entire codebase.
public enum AppConstants {
    /// The public brand/display name of the application.
    public static let appName = "LocalFlow"
    
    /// The bundle identifier for the application.
    public static let bundleIdentifier = "com.localflow.mac"
    
    /// Application version string, read from the bundle so it can never drift
    /// from `Config/Info.plist`.
    public static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.2"
    }
    
    /// Where people buy and manage a Pro license.
    public static let purchaseURL = URL(string: "https://loomlytic.com/#pricing")!

    /// One-time price shown in the app, kept in sync with the website.
    public static let proPrice = "€15"

    /// Base directory in Application Support for storing models, caches, and local configurations.
    public static var applicationSupportDirectory: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent(appName, isDirectory: true)
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }
    
    /// Directory dedicated to storing speech-to-text models (WhisperKit / CoreML & whisper.cpp GGML).
    public static var modelsDirectory: URL {
        let dir = applicationSupportDirectory.appendingPathComponent("Models", isDirectory: true)
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Directory dedicated to WhisperKit CoreML models.
    public static var whisperKitModelsDirectory: URL {
        let dir = modelsDirectory.appendingPathComponent("WhisperKit", isDirectory: true)
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Directory dedicated to whisper.cpp GGML models.
    public static var whisperCppModelsDirectory: URL {
        let dir = modelsDirectory.appendingPathComponent("WhisperCpp", isDirectory: true)
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Directory dedicated to Local LLM models (e.g. Qwen GGUF).
    public static var llmModelsDirectory: URL {
        let dir = modelsDirectory.appendingPathComponent("LLM", isDirectory: true)
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Path for storing user custom dictionary.
    public static var dictionaryFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("dictionary.json")
    }
    
    /// Path for storing local history.
    public static var historyFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("history.json")
    }
}
