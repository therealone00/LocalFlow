import Foundation
import CoreGraphics
import AppKit

public enum HotkeyAction: Sendable {
    case pushToTalkDown
    case pushToTalkUp
    case toggleHandsFree
    case cancelSession
    case pasteLastDictation
}

@MainActor
public final class GlobalHotkeyManager: ObservableObject {
    public static let shared = GlobalHotkeyManager()
    
    public var onAction: ((HotkeyAction) -> Void)?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    private var isKeyDown = false
    private var lastKeyDownTime: Date?
    
    public init() {}
    
    public func start() {
        stop()
        setupEventTap()
        setupNSEventMonitors()
    }
    
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        isKeyDown = false
    }
    
    // MARK: - Event Tap Setup
    
    private func setupEventTap() {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                (1 << CGEventType.keyDown.rawValue) |
                                (1 << CGEventType.keyUp.rawValue)
        
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            AppLogger.input.warning("Could not create CGEventTap directly (Accessibility may not be granted yet). NSEvent monitors will act as primary/fallback.")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        AppLogger.input.info("Global CGEventTap successfully established.")
    }
    
    // MARK: - NSEvent Monitors Setup
    
    private func setupNSEventMonitors() {
        // Global monitor for events delivered to other applications
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            self?.handleNSEvent(event)
        }
        
        // Local monitor for events delivered to LocalFlow's own windows (Settings, Onboarding)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            self?.handleNSEvent(event)
            return event
        }
        AppLogger.input.info("NSEvent global and local monitors registered.")
    }
    
    // MARK: - Event Handling
    
    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            AppLogger.input.warning("CGEventTap disabled by macOS (\(type.rawValue)). Auto-reenabling.")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        processInput(type: type, keyCode: keyCode, cgFlags: flags, nsModifierFlags: nil)
        return Unmanaged.passRetained(event)
    }
    
    private func handleNSEvent(_ event: NSEvent) {
        // If CGEventTap is already running, skip redundant NSEvent processing to avoid double-triggers
        if eventTap != nil {
            return
        }
        
        let type: CGEventType
        switch event.type {
        case .flagsChanged: type = .flagsChanged
        case .keyDown: type = .keyDown
        case .keyUp: type = .keyUp
        default: return
        }
        
        let keyCode = Int(event.keyCode)
        processInput(type: type, keyCode: keyCode, cgFlags: nil, nsModifierFlags: event.modifierFlags)
    }
    
    private var isHandsFreeMode = false
    private var keyDownTime: Date?
    
    public func resetHandsFreeState() {
        isHandsFreeMode = false
        isKeyDown = false
        keyDownTime = nil
    }
    
    private func processInput(type: CGEventType, keyCode: Int, cgFlags: CGEventFlags?, nsModifierFlags: NSEvent.ModifierFlags?) {
        let settings = SettingsManager.shared.settings
        
        // Check for ESC key to cancel dictation
        if type == .keyDown && keyCode == 53 {
            isHandsFreeMode = false
            isKeyDown = false
            DispatchQueue.main.async { [weak self] in
                self?.onAction?(.cancelSession)
            }
            return
        }
        
        // If in hands-free mode, pressing Return/Enter stops and processes
        if isHandsFreeMode && type == .keyDown && (keyCode == 36 || keyCode == 76) {
            isHandsFreeMode = false
            isKeyDown = false
            DispatchQueue.main.async { [weak self] in
                self?.onAction?(.pushToTalkUp)
            }
            return
        }
        
        // `.resolved` maps the unconfigurable .custom case onto Hold Fn.
        switch settings.shortcutMode.resolved {
        case .holdFn:
            if type == .flagsChanged {
                let isFnActive: Bool
                if let flags = cgFlags {
                    isFnActive = flags.contains(.maskSecondaryFn)
                } else if let mod = nsModifierFlags {
                    isFnActive = mod.contains(.function)
                } else {
                    isFnActive = false
                }
                handlePushToTalkState(isPressed: isFnActive)
            }
            
        case .rightOption:
            if type == .flagsChanged {
                let isOptActive: Bool
                if let flags = cgFlags {
                    isOptActive = flags.contains(.maskAlternate) && (keyCode == 61 || keyCode == 58)
                } else if let mod = nsModifierFlags {
                    isOptActive = mod.contains(.option) && (keyCode == 61 || keyCode == 58)
                } else {
                    isOptActive = false
                }
                handlePushToTalkState(isPressed: isOptActive)
            }
            
        case .dictationKey:
            // Keycode 96 / F5 on MacBooks
            if type == .keyDown && keyCode == 96 {
                handlePushToTalkState(isPressed: true)
            } else if type == .keyUp && keyCode == 96 {
                handlePushToTalkState(isPressed: false)
            }
            
        case .fnSpace:
            if type == .keyDown && keyCode == 49 { // Space
                let hasFn = cgFlags?.contains(.maskSecondaryFn) ?? nsModifierFlags?.contains(.function) ?? false
                if hasFn {
                    DispatchQueue.main.async { [weak self] in
                        self?.onAction?(.toggleHandsFree)
                    }
                }
            }
            
        case .controlOption:
            if type == .flagsChanged {
                let isCtrlOpt: Bool
                if let flags = cgFlags {
                    isCtrlOpt = flags.contains(.maskControl) && flags.contains(.maskAlternate)
                } else if let mod = nsModifierFlags {
                    isCtrlOpt = mod.contains(.control) && mod.contains(.option)
                } else {
                    isCtrlOpt = false
                }
                handlePushToTalkState(isPressed: isCtrlOpt)
            }
            
        case .custom:
            // Unreachable: `.resolved` never returns .custom. Kept so the
            // switch stays exhaustive if a recorder is added later.
            break
        }
    }
    
    private func handlePushToTalkState(isPressed: Bool) {
        if isPressed && !isKeyDown {
            isKeyDown = true
            let now = Date()
            keyDownTime = now
            
            // If already in hands-free mode, pressing the hotkey again completes and inserts!
            if isHandsFreeMode {
                isHandsFreeMode = false
                DispatchQueue.main.async { [weak self] in
                    self?.onAction?(.pushToTalkUp)
                }
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.onAction?(.pushToTalkDown)
            }
        } else if !isPressed && isKeyDown {
            isKeyDown = false
            guard !isHandsFreeMode else { return }
            
            let now = Date()
            let duration = keyDownTime.map { now.timeIntervalSince($0) } ?? 1.0
            
            if duration < 0.35 {
                // Quick tap: switch to hands-free toggle mode so user doesn't need to keep holding!
                isHandsFreeMode = true
                DispatchQueue.main.async { [weak self] in
                    self?.onAction?(.toggleHandsFree)
                }
            } else {
                // Held down: push-to-talk release -> stop and insert!
                DispatchQueue.main.async { [weak self] in
                    self?.onAction?(.pushToTalkUp)
                }
            }
        }
    }
}
