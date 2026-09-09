import SwiftUI

public struct DictionarySettingsView: View {
    @ObservedObject var dictionaryManager = DictionaryManager.shared
    
    @State private var newSpoken = ""
    @State private var newWritten = ""
    @State private var isCaseSensitive = false
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Personal Dictionary & Custom Words")
                .font(.headline)
            
            Text("Teach \(AppConstants.appName) specific names, technical terms, or auto-replacements.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                TextField("Spoken phrase (e.g. 'local flow')", text: $newSpoken)
                    .textFieldStyle(.roundedBorder)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                TextField("Written replacement (e.g. 'LocalFlow')", text: $newWritten)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: addEntry) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(newSpoken.trimmingCharacters(in: .whitespaces).isEmpty || newWritten.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            List {
                ForEach(dictionaryManager.entries) { entry in
                    HStack {
                        Text(entry.spokenPhrase)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(entry.writtenReplacement)
                            .foregroundColor(.accentColor)
                        Spacer()
                        Button(role: .destructive) {
                            dictionaryManager.removeEntry(id: entry.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .padding()
    }
    
    private func addEntry() {
        dictionaryManager.addEntry(
            spokenPhrase: newSpoken,
            writtenReplacement: newWritten,
            isCaseSensitive: isCaseSensitive
        )
        newSpoken = ""
        newWritten = ""
    }
}
