import SwiftUI

public struct DictionarySettingsView: View {
    @ObservedObject var dictionaryManager = DictionaryManager.shared

    @State private var newSpoken = ""
    @State private var newWritten = ""
    @State private var isCaseSensitive = false
    @State private var searchText = ""
    @FocusState private var spokenFieldFocused: Bool

    public init() {}

    private var canAdd: Bool {
        !newSpoken.trimmingCharacters(in: .whitespaces).isEmpty
            && !newWritten.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// True when saving would silently replace an existing rule.
    private var overwritesExisting: Bool {
        let phrase = newSpoken.trimmingCharacters(in: .whitespaces)
        guard !phrase.isEmpty else { return false }
        return dictionaryManager.entries.contains {
            $0.spokenPhrase.caseInsensitiveCompare(phrase) == .orderedSame
        }
    }

    private var filteredEntries: [DictionaryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return dictionaryManager.entries }
        return dictionaryManager.entries.filter {
            $0.spokenPhrase.localizedCaseInsensitiveContains(query)
                || $0.writtenReplacement.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        SettingsPane(
            title: "Dictionary",
            subtitle: "Teach \(AppConstants.appName) names, jargon and shorthand it should always spell your way.",
            systemImage: "character.book.closed"
        ) {
            SettingsCard(
                "Add a Rule",
                footnote: overwritesExisting
                    ? "A rule for “\(newSpoken.trimmingCharacters(in: .whitespaces))” already exists and will be replaced."
                    : "Whenever you say the phrase on the left, the text on the right is inserted instead."
            ) {
                HStack(spacing: DS.Spacing.s) {
                    TextField("You say…", text: $newSpoken)
                        .textFieldStyle(.roundedBorder)
                        .focused($spokenFieldFocused)
                        .onSubmit { if canAdd { addEntry() } }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("…this is written", text: $newWritten)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { if canAdd { addEntry() } }

                    Button("Add", action: addEntry)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAdd)
                }

                Toggle("Match capitalisation exactly", isOn: $isCaseSensitive)
                    .toggleStyle(.checkbox)
                    .font(DS.Font.rowDetail)
            }

            SettingsCard("Rules (\(dictionaryManager.entries.count))") {
                if dictionaryManager.entries.isEmpty {
                    emptyState
                } else {
                    if dictionaryManager.entries.count > 6 {
                        TextField("Search rules", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                    }

                    if filteredEntries.isEmpty {
                        Text("No rule matches “\(searchText)”.")
                            .font(DS.Font.rowDetail)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DS.Spacing.m)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(filteredEntries) { entry in
                                DictionaryRow(entry: entry) {
                                    dictionaryManager.removeEntry(id: entry.id)
                                }
                                if entry.id != filteredEntries.last?.id {
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
            Image(systemName: "character.book.closed")
                .font(.system(size: 26))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No rules yet")
                .font(.system(size: 13, weight: .semibold))

            Text("Add your first rule above — for example “local flow” → “LocalFlow”.")
                .font(DS.Font.rowDetail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    private func addEntry() {
        dictionaryManager.addEntry(
            spokenPhrase: newSpoken,
            writtenReplacement: newWritten,
            isCaseSensitive: isCaseSensitive
        )
        newSpoken = ""
        newWritten = ""
        isCaseSensitive = false
        spokenFieldFocused = true
    }
}

private struct DictionaryRow: View {
    let entry: DictionaryEntry
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Text(entry.spokenPhrase)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(entry.writtenReplacement)
                .font(.system(size: 12))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)

            if entry.isCaseSensitive {
                StatusChip("Aa", kind: .neutral)
            }

            Spacer(minLength: DS.Spacing.s)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .opacity(isHovering ? 1 : 0.25)
            .help("Delete this rule")
        }
        .padding(.vertical, DS.Spacing.s)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
