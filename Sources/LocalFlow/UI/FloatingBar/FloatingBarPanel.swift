import Foundation
import AppKit
import SwiftUI
import Combine

/// Borderless panel that hosts the floating bar.
///
/// The panel sizes itself to whatever the SwiftUI content reports, so the bar
/// never has a width that does not match its contents, and it forwards mouse
/// events to the app underneath unless the bar is actually showing controls.
@MainActor
public final class FloatingBarPanel: NSPanel {
    public static let shared = FloatingBarPanel()

    private var cancellables = Set<AnyCancellable>()
    private var contentSize: CGSize = CGSize(width: 320, height: 84)

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 84),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = true
        self.animationBehavior = .none
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let hostingView = NSHostingView(
            rootView: FloatingBarView(onSizeChange: { [weak self] size in
                self?.contentSizeDidChange(size)
            })
        )
        self.contentView = hostingView

        setupStateObservation()
    }

    override public var canBecomeKey: Bool { false }
    override public var canBecomeMain: Bool { false }

    // MARK: - State

    private func setupStateObservation() {
        AppState.shared.$dictationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.apply(state: state)
            }
            .store(in: &cancellables)

        // Re-position when the user changes where the bar should appear.
        SettingsManager.shared.$settings
            .map(\.floatingBarPosition)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isVisible else { return }
                self.reposition()
            }
            .store(in: &cancellables)
    }

    private func apply(state: DictationState) {
        // The bar only swallows clicks while it is offering something to click.
        self.ignoresMouseEvents = !state.isInteractive

        guard state != .idle else {
            hide()
            return
        }

        reposition()

        if !isVisible {
            alphaValue = 0.0
            orderFrontRegardless()
            fade(to: 1.0)
        }
    }

    private func hide() {
        guard isVisible else { return }
        fade(to: 0.0) { [weak self] in
            self?.orderOut(nil)
        }
    }

    private func fade(to alpha: CGFloat, completion: (() -> Void)? = nil) {
        guard !DS.Motion.isReduced else {
            alphaValue = alpha
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = alpha
        } completionHandler: {
            completion?()
        }
    }

    // MARK: - Sizing

    private func contentSizeDidChange(_ size: CGSize) {
        guard abs(size.width - contentSize.width) > 0.5 || abs(size.height - contentSize.height) > 0.5 else {
            return
        }
        contentSize = size
        // Deferred so the frame change never happens inside a SwiftUI layout pass.
        DispatchQueue.main.async { [weak self] in
            self?.reposition()
        }
    }

    // MARK: - Positioning

    public func updatePosition() {
        reposition()
    }

    /// Places the bar on the screen the user is actually looking at — the one
    /// under the pointer — rather than always on the primary display.
    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func reposition() {
        guard let screen = activeScreen() else { return }
        let visible = screen.visibleFrame
        let size = contentSize
        let origin: CGPoint

        switch SettingsManager.shared.settings.floatingBarPosition {
        case .bottomCenter:
            origin = CGPoint(
                x: visible.midX - size.width / 2,
                y: visible.minY + 48 - FloatingBarView.shadowInset
            )
        case .nearCursor:
            let mouse = NSEvent.mouseLocation
            var x = mouse.x - size.width / 2
            var y = mouse.y - size.height - 12
            // Keep the whole bar on screen, including its transparent margin.
            x = min(max(x, visible.minX), visible.maxX - size.width)
            if y < visible.minY {
                y = mouse.y + 24
            }
            y = min(max(y, visible.minY), visible.maxY - size.height)
            origin = CGPoint(x: x, y: y)
        }

        let frame = NSRect(origin: origin, size: size)
        guard frame != self.frame else { return }
        setFrame(frame, display: true, animate: false)
    }
}
