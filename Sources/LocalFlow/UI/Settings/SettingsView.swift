import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case dictation = "Dictation"
    case intelligence = "Intelligence"
    case models = "Models"
    case dictionary = "Dictionary"
    case appearance = "Appearance"
    case privacy = "Privacy"
    case advanced = "Advanced"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .dictation: return "mic"
        case .intelligence: return "sparkles"
        case .models: return "cpu"
        case .dictionary: return "character.book.closed"
        case .appearance: return "paintpalette"
        case .privacy: return "lock.shield"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

public struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.iconName)
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .dictation:
                    DictationSettingsView()
                case .intelligence:
                    IntelligenceSettingsView()
                case .models:
                    ModelsSettingsView()
                case .dictionary:
                    DictionarySettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .privacy:
                    PrivacySettingsView()
                case .advanced:
                    AdvancedSettingsView()
                }
            }
            .navigationTitle(selectedTab.rawValue)
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}
