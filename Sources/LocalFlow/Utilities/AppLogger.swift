import Foundation
import os

/// Structured system logging using os.Logger.
/// Ensures that private user transcriptions or spoken words are never logged to disk or console.
public enum AppLogger {
    private static let subsystem = AppConstants.bundleIdentifier
    
    public static let app = Logger(subsystem: subsystem, category: "App")
    public static let audio = Logger(subsystem: subsystem, category: "Audio")
    public static let transcription = Logger(subsystem: subsystem, category: "Transcription")
    public static let intelligence = Logger(subsystem: subsystem, category: "Intelligence")
    public static let input = Logger(subsystem: subsystem, category: "Input")
    public static let accessibility = Logger(subsystem: subsystem, category: "Accessibility")
    public static let models = Logger(subsystem: subsystem, category: "Models")
    public static let ui = Logger(subsystem: subsystem, category: "UI")
}
