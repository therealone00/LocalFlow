import Foundation

/// Everything that Pro unlocks.
///
/// The free tier is a complete dictation app: unlimited dictation, rule-based
/// cleanup, and the Tiny and Base models. Pro adds the parts that cost real
/// work to build and maintain.
public enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case smartCleanup
    case largeModel
    case appContextStyles
    case unlimitedDictionary
    case fullHistory

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .smartCleanup: return "Smart AI polish"
        case .largeModel: return "Whisper Small model"
        case .appContextStyles: return "Per-app writing styles"
        case .unlimitedDictionary: return "Unlimited dictionary"
        case .fullHistory: return "Full history"
        }
    }

    public var summary: String {
        switch self {
        case .smartCleanup:
            return "Runs a local language model over the transcript for the cleanest prose, beyond what rules alone can do."
        case .largeModel:
            return "The most accurate Whisper tier, for technical vocabulary and long sentences."
        case .appContextStyles:
            return "Writes formally in Mail, casually in chat, and code-aware in editors."
        case .unlimitedDictionary:
            return "Free covers \(ProFeature.unlimitedDictionary.freeLimit ?? 0) dictionary rules. Pro removes the ceiling."
        case .fullHistory:
            return "Free keeps the newest \(ProFeature.fullHistory.freeLimit ?? 0) transcripts within reach. Pro opens the whole archive."
        }
    }

    /// How much of this feature the free tier gets, when it is countable.
    public var freeLimit: Int? {
        switch self {
        case .unlimitedDictionary: return 10
        case .fullHistory: return 25
        case .smartCleanup, .largeModel, .appContextStyles: return nil
        }
    }
}
