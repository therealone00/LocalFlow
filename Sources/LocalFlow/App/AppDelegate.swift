import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public static var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Hide dock icon; make pure menu bar agent
        NSApp.setActivationPolicy(.accessory)

        ThemeController.shared.start()
        setupStatusItem()
        observeState()
        setupFloatingBar()
        setupHotkeys()
        setupSleepWakeObservers()
        prewarmSpeechEngine()

        // Verify Accessibility permission and register app with macOS Accessibility list
        if !AccessibilityManager.shared.checkPermission() {
            AccessibilityManager.shared.promptForAccessibility()
        }

        // Check if onboarding needs to be shown
        if !SettingsManager.shared.settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.stop()
    }

    /// Opening the app again is the way back in when the menu bar icon is
    /// hidden, so re-launching always surfaces Settings.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return true
    }

    // MARK: - Status item

    private func setupStatusItem() {
        guard SettingsManager.shared.settings.showMenuBarIcon else { return }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        updateStatusItemAppearance(for: AppState.shared.dictationState)
        rebuildMenu(menu)
    }

    private func teardownStatusItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    private func observeState() {
        AppState.shared.$dictationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateStatusItemAppearance(for: state)
            }
            .store(in: &cancellables)

        SettingsManager.shared.$settings
            .map(\.showMenuBarIcon)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                if isVisible {
                    self?.setupStatusItem()
                } else {
                    self?.teardownStatusItem()
                }
            }
            .store(in: &cancellables)
    }

    /// The menu bar icon carries the dictation state so the app is legible even
    /// when the floating bar is off-screen or on another display.
    private func updateStatusItemAppearance(for state: DictationState) {
        guard let button = statusItem?.button else { return }

        let symbol: String
        let tint: NSColor?

        switch state {
        case .idle, .cancelled:
            symbol = "waveform"
            tint = nil
        case .preparing:
            symbol = "waveform"
            tint = .secondaryLabelColor
        case .listening:
            symbol = "waveform.circle.fill"
            tint = .systemRed
        case .processing:
            symbol = "waveform.circle"
            tint = .controlAccentColor
        case .success:
            symbol = "checkmark.circle.fill"
            tint = .systemGreen
        case .error:
            symbol = "exclamationmark.triangle.fill"
            tint = .systemOrange
        }

        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: AppConstants.appName)
            ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: AppConstants.appName)
        button.contentTintColor = tint
        button.toolTip = "\(AppConstants.appName) — \(state.menuBarSummary)"
    }

    // MARK: - Menu

    public func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let state = AppState.shared.dictationState
        let shortcut = SettingsManager.shared.settings.shortcutMode

        let statusMenuItem = NSMenuItem(title: state.menuBarSummary, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        if state == .listening {
            menu.addItem(NSMenuItem(title: "Stop & Insert", action: #selector(stopDictation), keyEquivalent: "d"))
            menu.addItem(NSMenuItem(title: "Cancel Dictation", action: #selector(cancelDictation), keyEquivalent: "."))
        } else {
            let start = NSMenuItem(title: "Start Dictation", action: #selector(startDictation), keyEquivalent: "d")
            start.toolTip = "Or press \(shortcut.displayName) anywhere"
            menu.addItem(start)
            menu.addItem(NSMenuItem(title: "Hands-Free Dictation", action: #selector(toggleHandsFree), keyEquivalent: "h"))
        }

        let hint = NSMenuItem(title: "Shortcut: \(shortcut.displayName)", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(NSMenuItem.separator())

        let recent = HistoryManager.shared.items.prefix(5)
        if !recent.isEmpty {
            menu.addItem(NSMenuItem(title: "Paste Last Dictation", action: #selector(pasteLastDictation), keyEquivalent: "v"))

            let recentItem = NSMenuItem(title: "Copy Recent", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for item in recent {
                let truncated = item.text.count > 44 ? String(item.text.prefix(44)) + "…" : item.text
                let entry = NSMenuItem(title: truncated, action: #selector(copyHistoryItem(_:)), keyEquivalent: "")
                entry.representedObject = item.text
                entry.toolTip = "\(item.targetAppName) — \(item.text)"
                submenu.addItem(entry)
            }
            recentItem.submenu = submenu
            menu.addItem(recentItem)

            menu.addItem(NSMenuItem(title: "Show All History…", action: #selector(showHistory), keyEquivalent: "y"))
            menu.addItem(NSMenuItem.separator())
        }

        if !LicenseManager.shared.isPro {
            let upgrade = NSMenuItem(title: "Get LocalFlow Pro — \(AppConstants.proPrice) once", action: #selector(showLicense), keyEquivalent: "")
            upgrade.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            menu.addItem(upgrade)
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Setup Guide…", action: #selector(showOnboarding), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit \(AppConstants.appName)", action: #selector(quitApp), keyEquivalent: "q"))
    }

    private func setupFloatingBar() {
        _ = FloatingBarPanel.shared
    }

    private func setupHotkeys() {
        GlobalHotkeyManager.shared.onAction = { action in
            Task { @MainActor in
                AppState.shared.handleHotkeyAction(action)
            }
        }
        GlobalHotkeyManager.shared.start()
    }

    private func setupSleepWakeObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                GlobalHotkeyManager.shared.stop()
                AppState.shared.cancel()
            }
        }
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                GlobalHotkeyManager.shared.start()
            }
        }
    }

    private func prewarmSpeechEngine() {
        Task.detached(priority: .background) {
            let settings = await SettingsManager.shared.effectiveSettings
            if settings.prewarmPolicy != .never {
                _ = try? await TranscriptionCoordinator.shared.getEngine(settings: settings)
            }
        }
    }

    // MARK: - Actions

    @objc public func startDictation() {
        AppState.shared.startListening()
    }

    @objc public func stopDictation() {
        AppState.shared.stopListeningAndProcess()
    }

    @objc public func cancelDictation() {
        AppState.shared.cancel()
    }

    @objc public func toggleHandsFree() {
        AppState.shared.handleHotkeyAction(.toggleHandsFree)
    }

    @objc public func pasteLastDictation() {
        AppState.shared.pasteLastDictation()
    }

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc public func showHistory() {
        openSettings(tab: .history)
    }

    @objc public func showLicense() {
        openSettings(tab: .license)
    }

    @objc public func showSettings() {
        openSettings(tab: nil)
    }

    public func openSettings(tab: SettingsTab?) {
        if let tab {
            SettingsRouter.shared.selectedTab = tab
        }

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppConstants.appName) Settings"
        window.titlebarAppearsTransparent = false
        window.contentMinSize = NSSize(width: 740, height: 560)
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("LocalFlowSettingsWindow")
        window.center()
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func showOnboarding() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to \(AppConstants.appName)"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: OnboardingView())
        window.isReleasedWhenClosed = false
        window.center()
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
