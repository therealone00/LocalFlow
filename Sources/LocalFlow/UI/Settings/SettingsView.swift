import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    // Raw values are stable identifiers; `title` is what the UI shows.
    case general = "General"
    case dictation = "Dictation"
    case intelligence = "Intelligence"
    case dictionary = "Dictionary"
    case models = "Models"
    case history = "History"
    case privacy = "Privacy"
    case appearance = "Appearance"
    case advanced = "Advanced"
    case license = "Pro"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .dictation: return "mic"
        case .intelligence: return "sparkles"
        case .dictionary: return "character.book.closed"
        case .models: return "cpu"
        case .history: return "clock.arrow.circlepath"
        case .privacy: return "lock.shield"
        case .appearance: return "paintpalette"
        case .advanced: return "slider.horizontal.3"
        case .license: return "seal"
        }
    }

    /// Sidebar grouping, so nine panes stay scannable.
    public enum Group: String, CaseIterable, Identifiable {
        case setup = "Setup"
        case text = "Text"
        case engine = "Engine"
        case data = "Data"
        case account = "License"

        public var id: String { rawValue }

        public var tabs: [SettingsTab] {
            switch self {
            case .setup: return [.general, .dictation, .appearance]
            case .text: return [.intelligence, .dictionary]
            case .engine: return [.models, .advanced]
            case .data: return [.history, .privacy]
            case .account: return [.license]
            }
        }
    }
}

/// Owns the selected settings tab so other parts of the app (the menu bar, the
/// floating bar) can deep-link into a pane without rebuilding the window.
@MainActor
public final class SettingsRouter: ObservableObject {
    public static let shared = SettingsRouter()

    @Published public var selectedTab: SettingsTab = .general

    public init() {}
}

public struct SettingsView: View {
    @ObservedObject private var router = SettingsRouter.shared

    public init() {}

    private var selectedTab: SettingsTab { router.selectedTab }

    public var body: some View {
        NavigationSplitView {
            List(selection: $router.selectedTab) {
                ForEach(SettingsTab.Group.allCases) { group in
                    Section(group.rawValue) {
                        ForEach(group.tabs) { tab in
                            NavigationLink(value: tab) {
                                Label(tab.title, systemImage: tab.iconName)
                            }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 176, ideal: 190, max: 220)
            .listStyle(.sidebar)
        } detail: {
            detailView
                .navigationTitle(selectedTab.title)
                .frame(minWidth: 520)
        }
        .frame(minWidth: 740, idealWidth: 820, minHeight: 560, idealHeight: 640)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .general: GeneralSettingsView()
        case .dictation: DictationSettingsView()
        case .intelligence: IntelligenceSettingsView()
        case .dictionary: DictionarySettingsView()
        case .models: ModelsSettingsView()
        case .history: HistorySettingsView()
        case .privacy: PrivacySettingsView()
        case .appearance: AppearanceSettingsView()
        case .advanced: AdvancedSettingsView()
        case .license: LicenseSettingsView()
        }
    }
}
