import Foundation

// Display metadata for the settings enums.
//
// The `rawValue` of each enum is the persisted storage key, so it must never
// change. Everything the UI shows is derived here instead, which keeps user
// settings decodable while labels are free to evolve.

public extension ShortcutMode {
    /// Short label used in pickers and menus.
    var displayName: String {
        switch self {
        case .holdFn: return "Hold Fn / Globe"
        case .rightOption: return "Hold Right Option"
        case .dictationKey: return "Dictation / Mic Key"
        case .fnSpace: return "Fn + Space"
        case .controlOption: return "Control + Option"
        case .custom: return "Custom Shortcut"
        }
    }

    /// One-line explanation of how the shortcut behaves.
    var summary: String {
        switch self {
        case .holdFn:
            return "Hold to talk, release to insert. The macOS default and the most comfortable option."
        case .rightOption:
            return "Hold to talk, release to insert. Use this if Fn is bound to Emoji or Input Source."
        case .dictationKey:
            return "Uses the dedicated microphone key found on Mac keyboards."
        case .fnSpace:
            return "Press Fn + Space to start, press again to stop."
        case .controlOption:
            return "Press Control + Option to start, press again to stop."
        case .custom:
            return "Trigger dictation with your own key combination."
        }
    }

    /// True when the mode records only while the key is held down.
    var isPushToTalk: Bool {
        switch self {
        case .holdFn, .rightOption, .dictationKey: return true
        case .fnSpace, .controlOption, .custom: return false
        }
    }

    /// Symbols to render as keycaps.
    func keycaps(customKeyName: String = "Space") -> [String] {
        switch self {
        case .holdFn: return ["fn"]
        case .rightOption: return ["⌥"]
        case .dictationKey: return ["🎙"]
        case .fnSpace: return ["fn", "Space"]
        case .controlOption: return ["⌃", "⌥"]
        case .custom: return [customKeyName]
        }
    }
}

public extension IntelligenceTier {
    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .balanced: return "Balanced"
        case .smart: return "Smart"
        }
    }

    var summary: String {
        switch self {
        case .fast:
            return "Deterministic rules only. Lowest latency and no extra memory."
        case .balanced:
            return "Rules plus targeted AI passes. Recommended for everyday dictation."
        case .smart:
            return "Full local AI polish for the cleanest prose. Adds a moment of latency."
        }
    }
}

public extension SpeechModelTier {
    var sizeLabel: String {
        switch self {
        case .tiny: return "~75 MB"
        case .base: return "~140 MB"
        case .small: return "~470 MB"
        }
    }
}

public extension ModelPrewarmPolicy {
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .always: return "Always"
        case .never: return "On demand"
        }
    }

    var summary: String {
        switch self {
        case .auto: return "Keeps the model warm while you dictate and releases it when idle."
        case .always: return "Fastest first word, at the cost of permanently held RAM."
        case .never: return "Lowest memory use. The first dictation after launch is slower."
        }
    }
}

public extension FloatingBarPosition {
    var displayName: String {
        switch self {
        case .bottomCenter: return "Bottom Center"
        case .nearCursor: return "Near Cursor"
        }
    }
}

public extension FloatingBarSize {
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .compact: return "Compact"
        }
    }

    var isCompact: Bool { self == .compact }
}

public extension AppTheme {
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
