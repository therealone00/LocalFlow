import Foundation

/// A custom user dictionary entry for spoken phrase replacements or technical terms.
public struct DictionaryEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var spokenPhrase: String
    public var writtenReplacement: String
    public var isCaseSensitive: Bool
    
    public init(
        id: UUID = UUID(),
        spokenPhrase: String,
        writtenReplacement: String,
        isCaseSensitive: Bool = false
    ) {
        self.id = id
        self.spokenPhrase = spokenPhrase
        self.writtenReplacement = writtenReplacement
        self.isCaseSensitive = isCaseSensitive
    }
}
