import SwiftUI

public struct ModelsSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var licenseManager = LicenseManager.shared

    public init() {}

    public var body: some View {
        SettingsPane(
            title: "Models",
            subtitle: "Speech models are downloaded once and then run entirely offline.",
            systemImage: "cpu"
        ) {
            SettingsCard(
                "Speech Recognition",
                footnote: "Models run on the Apple Neural Engine and GPU. Audio is never transmitted."
            ) {
                ForEach(modelManager.availableModels) { model in
                    ModelRow(
                        model: model,
                        isActive: settingsManager.effectiveSettings.speechModelTier == model.tier,
                        isLocked: model.tier == .small && !licenseManager.isPro,
                        downloadStatus: modelManager.currentDownloadStatus,
                        onSelect: { settingsManager.settings.speechModelTier = model.tier },
                        onDownload: { modelManager.downloadModel(tier: model.tier) },
                        onCancel: { modelManager.cancelDownload() },
                        onDelete: { try? modelManager.deleteModel(tier: model.tier) }
                    )
                }

                if !licenseManager.isPro {
                    ProUpsellRow(.largeModel, compact: true)
                }
            }

            SettingsCard("Text Cleanup Model") {
                SettingRow(
                    "Qwen2.5 via llama.cpp",
                    detail: "Optional. Powers the Smart cleanup level for the most polished prose."
                ) {
                    StatusChip(
                        LocalLLMCleaner.shared.isAvailable ? "INSTALLED" : "NOT INSTALLED",
                        kind: LocalLLMCleaner.shared.isAvailable ? .positive : .neutral
                    )
                }
            }
        }
    }
}

private struct ModelRow: View {
    let model: ModelInfo
    let isActive: Bool
    let isLocked: Bool
    let downloadStatus: String
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary.opacity(0.5))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.s) {
                        Text(model.tier.displayName)
                            .font(.system(size: 13, weight: .semibold))

                        Text(model.tier.sizeLabel)
                            .font(DS.Font.rowDetail)
                            .foregroundStyle(.secondary)

                        if isLocked {
                            ProBadge()
                        }
                        if model.tier == .base {
                            StatusChip("RECOMMENDED", kind: .neutral)
                        }
                        if isActive {
                            StatusChip("IN USE", kind: .positive)
                        }
                    }

                    Text(model.tier.description)
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DS.Spacing.m)

                actions
            }

            if model.isDownloading {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ProgressView(value: model.downloadProgress)
                        .progressViewStyle(.linear)
                    Text(downloadStatus.isEmpty ? "Downloading…" : downloadStatus)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 27)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .opacity(isLocked ? 0.55 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if model.isDownloaded && !isActive && !isLocked { onSelect() }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if isLocked {
            EmptyView()
        } else if model.isDownloading {
            Button("Cancel", action: onCancel)
                .controlSize(.small)
        } else if model.isDownloaded {
            HStack(spacing: DS.Spacing.s) {
                if !isActive {
                    Button("Use", action: onSelect)
                        .controlSize(.small)
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
                .help("Delete this model from disk")
                .disabled(isActive)
            }
        } else {
            Button("Download", action: onDownload)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}
