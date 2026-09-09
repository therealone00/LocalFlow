import Foundation

public struct ModelInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let tier: SpeechModelTier
    public let sizeDescription: String
    public var isDownloaded: Bool
    public var localSizeOnDisk: Int64
    public var isDownloading: Bool = false
    public var downloadProgress: Double = 0.0
}

@MainActor
public final class ModelManager: ObservableObject {
    public static let shared = ModelManager()
    
    @Published public private(set) var availableModels: [ModelInfo] = []
    @Published public private(set) var activeDownloadId: String? = nil
    @Published public private(set) var currentDownloadProgress: Double = 0.0
    @Published public private(set) var currentDownloadStatus: String = ""
    
    private var downloadTask: Task<Void, Never>?
    
    public init() {
        refreshModelStatus()
    }
    
    public func refreshModelStatus() {
        let fileManager = FileManager.default
        let wkDir = AppConstants.whisperKitModelsDirectory
        
        var models: [ModelInfo] = []
        for tier in SpeechModelTier.allCases {
            let modelFolder = wkDir.appendingPathComponent(tier.modelId)
            let exists = fileManager.fileExists(atPath: modelFolder.path)
            var sizeOnDisk: Int64 = 0
            if exists {
                sizeOnDisk = folderSize(url: modelFolder)
            }
            
            let sizeDesc: String
            switch tier {
            case .tiny: sizeDesc = "~75 MB"
            case .base: sizeDesc = "~140 MB"
            case .small: sizeDesc = "~470 MB"
            }
            
            models.append(ModelInfo(
                id: tier.modelId,
                name: tier.displayName,
                tier: tier,
                sizeDescription: sizeDesc,
                isDownloaded: exists && sizeOnDisk > 10_000_000,
                localSizeOnDisk: sizeOnDisk
            ))
        }
        
        self.availableModels = models
    }
    
    public func isModelDownloaded(tier: SpeechModelTier) -> Bool {
        let modelFolder = AppConstants.whisperKitModelsDirectory.appendingPathComponent(tier.modelId)
        return FileManager.default.fileExists(atPath: modelFolder.path) && folderSize(url: modelFolder) > 10_000_000
    }
    
    public func deleteModel(tier: SpeechModelTier) throws {
        let modelFolder = AppConstants.whisperKitModelsDirectory.appendingPathComponent(tier.modelId)
        if FileManager.default.fileExists(atPath: modelFolder.path) {
            try FileManager.default.removeItem(at: modelFolder)
        }
        refreshModelStatus()
    }
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        activeDownloadId = nil
        currentDownloadProgress = 0.0
        currentDownloadStatus = ""
        refreshModelStatus()
    }
    
    private func folderSize(url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
