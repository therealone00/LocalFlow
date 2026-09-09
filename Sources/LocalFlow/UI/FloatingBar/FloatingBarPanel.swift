import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
public final class FloatingBarPanel: NSPanel {
    public static let shared = FloatingBarPanel()
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        
        let hostingView = NSHostingView(rootView: FloatingBarView())
        self.contentView = hostingView
        
        setupStateObservation()
    }
    
    override public var canBecomeKey: Bool {
        return false
    }
    
    override public var canBecomeMain: Bool {
        return false
    }
    
    private func setupStateObservation() {
        AppState.shared.$dictationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                if state == .idle {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.2
                        self.animator().alphaValue = 0.0
                    } completionHandler: {
                        DispatchQueue.main.async {
                            self.orderOut(nil)
                        }
                    }
                } else {
                    self.updatePosition(for: state)
                    if !self.isVisible {
                        self.alphaValue = 0.0
                        self.orderFrontRegardless()
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.2
                            self.animator().alphaValue = 1.0
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    public func updatePosition() {
        updatePosition(for: AppState.shared.dictationState)
    }
    
    public func updatePosition(for state: DictationState) {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        
        let panelWidth: CGFloat
        switch state {
        case .idle:
            panelWidth = 240
        case .preparing:
            panelWidth = 220
        case .listening:
            panelWidth = 340
        case .processing:
            panelWidth = 300
        case .success:
            panelWidth = 200
        case .error(let msg):
            if msg.localizedCaseInsensitiveContains("Bedienungshilfen") || msg.localizedCaseInsensitiveContains("Accessibility") {
                panelWidth = 390
            } else {
                panelWidth = 280
            }
        case .cancelled:
            panelWidth = 200
        }
        
        let panelHeight: CGFloat = 48
        let x = screenRect.origin.x + (screenRect.width - panelWidth) / 2
        let y = screenRect.origin.y + 68
        
        let targetFrame = NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
        self.setFrame(targetFrame, display: true, animate: self.isVisible)
    }
}
