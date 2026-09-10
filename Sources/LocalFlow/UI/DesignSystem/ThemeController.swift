import AppKit
import Combine

/// Applies the user's theme preference to the whole application.
///
/// Without this the Appearance setting is decorative: `NSApp.appearance` has to
/// be set explicitly for Light/Dark to override the system setting.
@MainActor
public final class ThemeController {
    public static let shared = ThemeController()

    private var cancellable: AnyCancellable?

    public init() {}

    public func start() {
        apply(SettingsManager.shared.settings.theme)
        cancellable = SettingsManager.shared.$settings
            .map(\.theme)
            .removeDuplicates()
            .sink { [weak self] theme in
                self?.apply(theme)
            }
    }

    private func apply(_ theme: AppTheme) {
        switch theme {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
