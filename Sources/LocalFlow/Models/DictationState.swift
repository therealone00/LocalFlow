import Foundation

/// Represents the stages of a dictation workflow.
public enum DictationState: Equatable, Sendable {
    case idle
    case preparing
    case listening
    case processing(stage: ProcessingStage)
    case success
    case error(message: String)
    case cancelled
    
    public enum ProcessingStage: String, Equatable, Sendable, CaseIterable, Hashable {
        case transcribing = "Transcribing…"
        case polishing = "Polishing…"
        case inserting = "Inserting…"

        /// Pipeline order, used to render stage progress.
        public static let ordered: [ProcessingStage] = [.transcribing, .polishing, .inserting]

        public var order: Int {
            switch self {
            case .transcribing: return 0
            case .polishing: return 1
            case .inserting: return 2
            }
        }

        public var title: String {
            switch self {
            case .transcribing: return "Transcribing…"
            case .polishing: return "Polishing…"
            case .inserting: return "Inserting…"
            }
        }
    }

    /// Message used when insertion failed because Accessibility is not granted.
    /// The floating bar upgrades this into an actionable banner.
    public static let accessibilityErrorMessage = "Accessibility access required"

    public static func isAccessibilityMessage(_ message: String) -> Bool {
        message == accessibilityErrorMessage
            || message.localizedCaseInsensitiveContains("accessibility")
            || message.localizedCaseInsensitiveContains("bedienungshilfen")
    }

    /// Short human-readable status used by the menu bar item and its tooltip.
    public var menuBarSummary: String {
        switch self {
        case .idle: return "Ready to dictate"
        case .preparing: return "Starting…"
        case .listening: return "Recording…"
        case .processing(let stage): return stage.title
        case .success: return "Inserted"
        case .error(let message): return message
        case .cancelled: return "Cancelled"
        }
    }

    /// True while the bar shows controls the user can click.
    public var isInteractive: Bool {
        switch self {
        case .listening:
            return true
        case .error(let message):
            return DictationState.isAccessibilityMessage(message)
        default:
            return false
        }
    }
}
