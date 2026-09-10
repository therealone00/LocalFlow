import Foundation

/// Shortcut activation modes.
public enum ShortcutMode: String, Codable, CaseIterable, Sendable {
    case holdFn = "Hold Fn / Globe (Push-to-Talk)"
    case rightOption = "Hold Right Option (Push-to-Talk)"
    case dictationKey = "Mac Dictation / Mic Key"
    case fnSpace = "Fn + Space"
    case controlOption = "Control + Option"
    case custom = "Custom Shortcut"
}

/// Text intelligence cleanup tiers.
public enum IntelligenceTier: String, Codable, CaseIterable, Sendable {
    case fast = "Fast (Rule-based)"
    case balanced = "Balanced (Rules + Targeted AI)"
    case smart = "Smart (Full Local AI Polish)"
}

/// Whisper speech models available for local download.
public enum SpeechModelTier: String, Codable, CaseIterable, Sendable {
    case tiny = "Whisper Tiny (Fastest, ~75MB)"
    case base = "Whisper Base (Balanced, ~140MB)"
    case small = "Whisper Small (Accurate, ~470MB)"
    
    public var modelId: String {
        switch self {
        case .tiny: return "openai_whisper-tiny"
        case .base: return "openai_whisper-base"
        case .small: return "openai_whisper-small"
        }
    }
    
    public var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        }
    }
    
    public var description: String {
        switch self {
        case .tiny: return "Fastest speed, minimal RAM usage. Good for quick commands."
        case .base: return "Recommended. Best balance of high accuracy and low latency for German & English."
        case .small: return "Maximum accuracy for technical terms and complex sentences."
        }
    }
}

/// Model memory residency policy.
public enum ModelPrewarmPolicy: String, Codable, CaseIterable, Sendable {
    case auto = "Auto (Intelligent caching)"
    case always = "Always (Keep loaded in RAM)"
    case never = "Never (Load on demand)"
}

/// Floating bar position preference.
public enum FloatingBarPosition: String, Codable, CaseIterable, Sendable {
    case bottomCenter = "Bottom Center"
    case nearCursor = "Near Cursor"
}

/// Floating bar size preference.
public enum FloatingBarSize: String, Codable, CaseIterable, Sendable {
    case standard = "Standard"
    case compact = "Compact"
}

/// App theme preference.
public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

/// Full application user settings.
public struct LocalFlowSettings: Codable, Equatable, Sendable {
    // General
    public var launchAtLogin: Bool = true
    public var showMenuBarIcon: Bool = true
    public var soundEffectsEnabled: Bool = true
    
    // Dictation & Input
    public var shortcutMode: ShortcutMode = .holdFn
    public var doubleTapHandsFree: Bool = true
    public var selectedAudioDeviceUID: String? = nil
    public var language: String = "auto" // "auto", "de", "en"
    public var autoStopSilenceDuration: Double = 2.5
    
    // Text Intelligence
    public var intelligenceTier: IntelligenceTier = .balanced
    public var removeFillerWords: Bool = true
    public var resolveSelfCorrections: Bool = true
    public var smartPunctuation: Bool = true
    public var smartFormatting: Bool = true
    public var useAppContext: Bool = true
    public var useCursorContext: Bool = true
    
    // Models
    public var speechModelTier: SpeechModelTier = .base
    public var prewarmPolicy: ModelPrewarmPolicy = .auto
    public var transcriptionEngine: TranscriptionEngineType = .auto
    
    // Appearance
    public var theme: AppTheme = .system
    public var floatingBarPosition: FloatingBarPosition = .bottomCenter
    public var floatingBarSize: FloatingBarSize = .standard
    public var showLiveTranscript: Bool = false
    public var reduceMotion: Bool = false
    
    // Privacy
    //
    // There is no "never save audio" setting because there is no code path that
    // writes audio to disk. Samples live in memory for one transcription and
    // are released. A toggle would imply the alternative exists.
    public var saveDictationHistory: Bool = true
    
    // Onboarding
    public var hasCompletedOnboarding: Bool = false
    
    public init() {}
}
