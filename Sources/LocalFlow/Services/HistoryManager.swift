import Foundation

@MainActor
public final class HistoryManager: ObservableObject {
    public static let shared = HistoryManager()
    
    @Published public private(set) var items: [DictationHistoryItem] = []
    
    public init() {
        load()
    }
    
    public func record(appName: String, text: String, duration: TimeInterval) {
        let settings = SettingsManager.shared.settings
        guard settings.saveDictationHistory else { return }
        guard !text.isEmpty else { return }
        
        let item = DictationHistoryItem(
            timestamp: Date(),
            targetAppName: appName,
            text: text,
            duration: duration
        )
        
        items.insert(item, at: 0)
        
        // Cap at 100 entries
        if items.count > 100 {
            items = Array(items.prefix(100))
        }
        
        save()
    }
    
    public func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }
    
    public func clearAll() {
        items.removeAll()
        save()
    }
    
    public var lastDictationText: String? {
        items.first?.text
    }

    /// The transcripts the current tier can reach.
    ///
    /// Everything stays on disk regardless of tier — the free ceiling hides the
    /// older entries rather than deleting them, so buying Pro brings the whole
    /// archive back instead of revealing that it was thrown away.
    public var accessibleItems: [DictationHistoryItem] {
        guard let limit = LicenseManager.shared.limit(for: .fullHistory) else { return items }
        return Array(items.prefix(limit))
    }

    /// How many stored transcripts the free tier is currently hiding.
    public var lockedItemCount: Int {
        max(0, items.count - accessibleItems.count)
    }
    
    private func load() {
        let url = AppConstants.historyFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DictationHistoryItem].self, from: data) else {
            return
        }
        self.items = decoded
    }
    
    private func save() {
        let url = AppConstants.historyFileURL
        if let encoded = try? JSONEncoder().encode(items) {
            try? encoded.write(to: url)
        }
    }
}
