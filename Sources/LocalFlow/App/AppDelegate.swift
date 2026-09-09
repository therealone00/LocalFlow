import Foundation
import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: AppDelegate?
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Hide dock icon; make pure menu bar agent
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        setupFloatingBar()
        setupHotkeys()
        setupSleepWakeObservers()
        prewarmSpeechEngine()
        
        // Check if onboarding needs to be shown
        if !SettingsManager.shared.settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.stop()
    }
    
    // MARK: - Status Item
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: AppConstants.appName)
        }
        
        let menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: "\(AppConstants.appName): Ready", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Start Dictation", action: #selector(startDictation), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "Hands-Free Dictation", action: #selector(toggleHandsFree), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Paste Last Dictation", action: #selector(pasteLastDictation), keyEquivalent: "v"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Onboarding…", action: #selector(showOnboarding), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit \(AppConstants.appName)", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
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
            let settings = await SettingsManager.shared.settings
            if settings.prewarmPolicy != .never {
                _ = try? await TranscriptionCoordinator.shared.getEngine(settings: settings)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc public func startDictation() {
        AppState.shared.startListening()
    }
    
    @objc public func toggleHandsFree() {
        AppState.shared.handleHotkeyAction(.toggleHandsFree)
    }
    
    @objc public func pasteLastDictation() {
        AppState.shared.pasteLastDictation()
    }
    
    @objc public func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppConstants.appName) Settings"
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
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
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to \(AppConstants.appName)"
        window.center()
        window.contentView = NSHostingView(rootView: OnboardingView())
        window.isReleasedWhenClosed = false
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc public func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
