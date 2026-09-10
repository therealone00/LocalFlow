import Foundation

@MainActor
public final class DictionaryManager: ObservableObject {
    public static let shared = DictionaryManager()
    
    @Published public private(set) var entries: [DictionaryEntry] = []
    
    public init() {
        load()
    }
    
    /// Free-tier headroom. Existing rules always keep working — the ceiling
    /// only stops new ones being added, so upgrading never silently disables
    /// something the user set up earlier.
    public var canAddEntry: Bool {
        guard let limit = LicenseManager.shared.limit(for: .unlimitedDictionary) else { return true }
        return entries.count < limit
    }

    public func addEntry(spokenPhrase: String, writtenReplacement: String, isCaseSensitive: Bool = false) {
        let trimmedPhrase = spokenPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = writtenReplacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty, !trimmedReplacement.isEmpty else { return }

        // Replacing an existing rule is always allowed; only growing the list
        // is gated.
        let isReplacement = entries.contains {
            $0.spokenPhrase.caseInsensitiveCompare(trimmedPhrase) == .orderedSame
        }
        guard isReplacement || canAddEntry else { return }

        // Remove existing entry for same phrase if present
        entries.removeAll { $0.spokenPhrase.caseInsensitiveCompare(trimmedPhrase) == .orderedSame }
        
        let newEntry = DictionaryEntry(
            spokenPhrase: trimmedPhrase,
            writtenReplacement: trimmedReplacement,
            isCaseSensitive: isCaseSensitive
        )
        entries.append(newEntry)
        save()
    }
    
    public func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }
    
    public func applyDictionary(to text: String) -> String {
        var result = text
        for entry in entries {
            let options: NSString.CompareOptions = entry.isCaseSensitive ? [] : [.caseInsensitive]
            // Use word boundary regex for single words or exact string for phrases
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: entry.spokenPhrase) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: entry.isCaseSensitive ? [] : [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (result as NSString).length)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: entry.writtenReplacement)
            } else {
                result = result.replacingOccurrences(of: entry.spokenPhrase, with: entry.writtenReplacement, options: options)
            }
        }
        return result
    }
    
    private func load() {
        let url = AppConstants.dictionaryFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: data) else {
            // Populate defaults
            self.entries = [
                DictionaryEntry(spokenPhrase: "local flow", writtenReplacement: "LocalFlow"),
                DictionaryEntry(spokenPhrase: "swift ui", writtenReplacement: "SwiftUI"),
                DictionaryEntry(spokenPhrase: "open ai", writtenReplacement: "OpenAI"),
                DictionaryEntry(spokenPhrase: "x code", writtenReplacement: "Xcode")
            ]
            save()
            return
        }
        self.entries = decoded
    }
    
    private func save() {
        let url = AppConstants.dictionaryFileURL
        if let encoded = try? JSONEncoder().encode(entries) {
            try? encoded.write(to: url)
        }
    }
}
