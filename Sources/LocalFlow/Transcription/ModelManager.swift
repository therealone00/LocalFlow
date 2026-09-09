import Foundation
import WhisperKit

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
            let directFolder = wkDir.appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(tier.modelId)")
            let fallbackFolder = wkDir.appendingPathComponent(tier.modelId)
            
            var sizeOnDisk: Int64 = 0
            var exists = false
            
            if fileManager.fileExists(atPath: directFolder.path) {
                sizeOnDisk = folderSize(url: directFolder)
                exists = (sizeOnDisk > 10_000_000)
            } else if fileManager.fileExists(atPath: fallbackFolder.path) {
                sizeOnDisk = folderSize(url: fallbackFolder)
                exists = (sizeOnDisk > 10_000_000)
            }
            
            let sizeDesc: String
            switch tier {
            case .tiny: sizeDesc = "~75 MB"
            case .base: sizeDesc = "~140 MB"
            case .small: sizeDesc = "~470 MB"
            }
            
            let isDownloading = (activeDownloadId == tier.modelId)
            
            models.append(ModelInfo(
                id: tier.modelId,
                name: tier.displayName,
                tier: tier,
                sizeDescription: sizeDesc,
                isDownloaded: exists,
                localSizeOnDisk: sizeOnDisk,
                isDownloading: isDownloading,
                downloadProgress: isDownloading ? currentDownloadProgress : (exists ? 1.0 : 0.0)
            ))
        }
        
        self.availableModels = models
    }
    
    public func isModelDownloaded(tier: SpeechModelTier) -> Bool {
        let wkDir = AppConstants.whisperKitModelsDirectory
        let directFolder = wkDir.appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(tier.modelId)")
        let fallbackFolder = wkDir.appendingPathComponent(tier.modelId)
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directFolder.path) && folderSize(url: directFolder) > 10_000_000 {
            return true
        }
        if fileManager.fileExists(atPath: fallbackFolder.path) && folderSize(url: fallbackFolder) > 10_000_000 {
            return true
        }
        return false
    }
    
    public func downloadModel(tier: SpeechModelTier) {
        cancelDownload()
        
        activeDownloadId = tier.modelId
        currentDownloadProgress = 0.0
        currentDownloadStatus = "Starting download for \(tier.displayName)…"
        refreshModelStatus()
        
        downloadTask = Task {
            do {
                _ = try await WhisperKit.download(
                    variant: tier.modelId,
                    downloadBase: AppConstants.whisperKitModelsDirectory
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.currentDownloadProgress = progress.fractionCompleted
                        let pct = Int(progress.fractionCompleted * 100)
                        self?.currentDownloadStatus = "Downloading \(tier.displayName): \(pct)%"
                        self?.refreshModelStatus()
                    }
                }
                
                self.activeDownloadId = nil
                self.currentDownloadProgress = 1.0
                self.currentDownloadStatus = "\(tier.displayName) ready"
                self.refreshModelStatus()
                
                // Prewarm downloaded model
                _ = try? await TranscriptionCoordinator.shared.getEngine(settings: SettingsManager.shared.settings)
            } catch {
                self.activeDownloadId = nil
                self.currentDownloadStatus = "Download error: \(error.localizedDescription)"
                self.refreshModelStatus()
                AppLogger.models.error("Model download error: \(error.localizedDescription)")
            }
        }
    }
    
    public func deleteModel(tier: SpeechModelTier) throws {
        let wkDir = AppConstants.whisperKitModelsDirectory
        let directFolder = wkDir.appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(tier.modelId)")
        let fallbackFolder = wkDir.appendingPathComponent(tier.modelId)
        
        if FileManager.default.fileExists(atPath: directFolder.path) {
            try FileManager.default.removeItem(at: directFolder)
        }
        if FileManager.default.fileExists(atPath: fallbackFolder.path) {
            try FileManager.default.removeItem(at: fallbackFolder)
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
