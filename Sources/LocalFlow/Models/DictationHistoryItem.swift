import Foundation

/// Represents a saved local history item.
public struct DictationHistoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let targetAppName: String
    public let text: String
    public let duration: TimeInterval
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        targetAppName: String,
        text: String,
        duration: TimeInterval
    ) {
        self.id = id
        self.timestamp = timestamp
        self.targetAppName = targetAppName
        self.text = text
        self.duration = duration
    }
}
