import SwiftUI
import AppKit

/// Browsable list of past dictations.
///
/// Until now the last 100 transcripts were stored but only the newest five were
/// reachable, and only through a menu bar submenu. This makes the whole archive
/// searchable and re-usable.
public struct HistorySettingsView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    @ObservedObject var settingsManager = SettingsManager.shared

    @State private var searchText = ""
    @State private var copiedItemId: UUID?

    public init() {}

    private var filteredItems: [DictationHistoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return historyManager.items }
        return historyManager.items.filter {
            $0.text.localizedCaseInsensitiveContains(query)
                || $0.targetAppName.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        SettingsPane(
            title: "History",
            subtitle: "Everything you have dictated, stored locally on this Mac.",
            systemImage: "clock.arrow.circlepath"
        ) {
            if !settingsManager.settings.saveDictationHistory {
                SettingsCard {
                    SettingRow(
                        "History is turned off",
                        detail: "New dictations are not being recorded. Turn history back on in Privacy."
                    ) {
                        Button("Enable") {
                            settingsManager.settings.saveDictationHistory = true
                        }
                        .controlSize(.small)
                    }
                }
            }

            if historyManager.items.isEmpty {
                SettingsCard {
                    emptyState
                }
            } else {
                SettingsCard("\(historyManager.items.count) transcripts") {
                    TextField("Search transcripts", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    if filteredItems.isEmpty {
                        Text("Nothing matches “\(searchText)”.")
                            .font(DS.Font.rowDetail)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DS.Spacing.l)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(filteredItems) { item in
                                HistoryRow(
                                    item: item,
                                    justCopied: copiedItemId == item.id,
                                    onCopy: { copy(item) },
                                    onDelete: { historyManager.removeItem(id: item.id) }
                                )
                                if item.id != filteredItems.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.s) {
            Image(systemName: "waveform")
                .font(.system(size: 26))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No dictations yet")
                .font(.system(size: 13, weight: .semibold))

            Text("Hold \(settingsManager.settings.shortcutMode.displayName) anywhere on macOS and start talking.")
                .font(DS.Font.rowDetail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    private func copy(_ item: DictationHistoryItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        copiedItemId = item.id
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if copiedItemId == item.id { copiedItemId = nil }
        }
    }
}

private struct HistoryRow: View {
    let item: DictationHistoryItem
    let justCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isExpanded = false

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.s) {
                Text(item.targetAppName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(Self.relativeFormatter.localizedString(for: item.timestamp, relativeTo: Date()))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.8))

                Text("· \(item.text.split(separator: " ").count) words")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.8))

                Spacer(minLength: DS.Spacing.s)

                if justCopied {
                    StatusChip("COPIED", kind: .positive, systemImage: "checkmark")
                } else {
                    HStack(spacing: DS.Spacing.xs) {
                        Button(action: onCopy) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help("Copy to clipboard")

                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help("Delete this transcript")
                    }
                    .opacity(isHovering ? 1 : 0.25)
                }
            }

            Text(item.text)
                .font(.system(size: 12))
                .lineLimit(isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.vertical, DS.Spacing.s)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            withAnimation(DS.Motion.page) { isExpanded.toggle() }
        }
    }
}
