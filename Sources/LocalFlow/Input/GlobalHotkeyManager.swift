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
    private var isFnPressed = false
    private var lastFnPressTime: Date?
    
    public init() {}
    
    public func start() {
        stop()
        
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                (1 << CGEventType.keyDown.rawValue) |
                                (1 << CGEventType.keyUp.rawValue)
        
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            AppLogger.input.error("Failed to create CGEventTap. Ensure Accessibility permissions are granted.")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        AppLogger.input.info("Global CGEventTap successfully established.")
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
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabling by system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            AppLogger.input.warning("CGEventTap disabled by macOS (\(type.rawValue)). Auto-reenabling.")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        let settings = SettingsManager.shared.settings
        
        // Check for Escape to cancel while dictating
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 53 { // ESC key
                DispatchQueue.main.async { [weak self] in
                    self?.onAction?(.cancelSession)
                }
            }
        }
        
        switch settings.shortcutMode {
        case .holdFn:
            if type == .flagsChanged {
                let flags = event.flags
                let isFn = flags.contains(.maskSecondaryFn)
                
                if isFn && !isFnPressed {
                    isFnPressed = true
                    let now = Date()
                    if settings.doubleTapHandsFree, let last = lastFnPressTime, now.timeIntervalSince(last) < 0.35 {
                        // Double tap Fn detected -> toggle hands free
                        lastFnPressTime = nil
                        DispatchQueue.main.async { [weak self] in
                            self?.onAction?(.toggleHandsFree)
                        }
                    } else {
                        lastFnPressTime = now
                        DispatchQueue.main.async { [weak self] in
                            self?.onAction?(.pushToTalkDown)
                        }
                    }
                } else if !isFn && isFnPressed {
                    isFnPressed = false
                    DispatchQueue.main.async { [weak self] in
                        self?.onAction?(.pushToTalkUp)
                    }
                }
            }
            
        case .dictationKey:
            // Keycode for dedicated dictation / F5 key on modern MacBooks is 96 or special HID
            if type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == 96 { // F5 / Mic key
                    DispatchQueue.main.async { [weak self] in
                        self?.onAction?(.pushToTalkDown)
                    }
                }
            } else if type == .keyUp {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == 96 {
                    DispatchQueue.main.async { [weak self] in
                        self?.onAction?(.pushToTalkUp)
                    }
                }
            }
            
        case .fnSpace:
            if type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == 49 && event.flags.contains(.maskSecondaryFn) { // Fn + Space
                    DispatchQueue.main.async { [weak self] in
                        self?.onAction?(.toggleHandsFree)
                    }
                }
            }
            
        case .controlOption:
            if type == .flagsChanged {
                let flags = event.flags
                let isCtrlOpt = flags.contains(.maskControl) && flags.contains(.maskAlternate)
                if isCtrlOpt && !isFnPressed {
                    isFnPressed = true
                    DispatchQueue.main.async { [weak self] in
                        self?.onAction?(.pushToTalkDown)
                    }
                } else if !isCtrlOpt && isFnPressed {
                    isFnPressed = false
                    DispatchQueue.main.async { [weak self] in
                        self?.onAction?(.pushToTalkUp)
                    }
                }
            }
            
        case .custom:
            if type == .keyDown {
                let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
                if keyCode == settings.customShortcutKey {
                    DispatchQueue.main.async { [weak self] in
                        self?.onAction?(.toggleHandsFree)
                    }
                }
            }
        }
        
        return Unmanaged.passRetained(event)
    }
}
