import SwiftUI

public struct ModelsSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var modelManager = ModelManager.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Speech Recognition Models")
                    .font(.headline)
                
                Text("All models run 100% locally on your Mac's Neural Engine and GPU. No audio is ever transmitted.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(modelManager.availableModels) { model in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(model.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    if model.tier == .base {
                                        Text("RECOMMENDED")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .foregroundColor(.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(model.tier.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(model.sizeDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    if model.isDownloading {
                                        Button("Cancel") {
                                            modelManager.cancelDownload()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    } else if model.isDownloaded {
                                        if settingsManager.settings.speechModelTier == model.tier {
                                            Text("Active")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.green)
                                        } else {
                                            Button("Select") {
                                                settingsManager.settings.speechModelTier = model.tier
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                        
                                        Button(role: .destructive) {
                                            try? modelManager.deleteModel(tier: model.tier)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.borderless)
                                    } else {
                                        Button("Download") {
                                            modelManager.downloadModel(tier: model.tier)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                        
                        if model.isDownloading {
                            VStack(alignment: .leading, spacing: 4) {
                                ProgressView(value: model.downloadProgress)
                                Text(modelManager.currentDownloadStatus)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(settingsManager.settings.speechModelTier == model.tier ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
                }
                
                Divider()
                
                Text("Local AI Cleanup Model")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Qwen2.5 / llama.cpp")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Provides ultra-refined text cleanup for Smart intelligence tier.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(LocalLLMCleaner.shared.isAvailable ? "Available" : "Optional")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
        }
    }
}
