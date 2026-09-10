import SwiftUI
import AppKit

/// Central design tokens for LocalFlow.
///
/// Every spacing value, radius, duration and brand colour used by the UI is
/// defined here exactly once so that surfaces stay visually consistent and a
/// single change propagates through the whole app.
public enum DS {

    // MARK: - Spacing

    public enum Spacing {
        public static let hair: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    // MARK: - Corner radii

    public enum Radius {
        public static let small: CGFloat = 6
        public static let medium: CGFloat = 10
        public static let large: CGFloat = 14
        public static let pill: CGFloat = 999
    }

    // MARK: - Brand colours

    public enum Palette {
        /// Warm coral — start of the brand ramp.
        public static let coral = Color(red: 1.00, green: 0.42, blue: 0.28)
        /// Violet — middle of the brand ramp.
        public static let violet = Color(red: 0.72, green: 0.25, blue: 1.00)
        /// Cyan — end of the brand ramp.
        public static let cyan = Color(red: 0.15, green: 0.78, blue: 1.00)

        public static let recording = Color(red: 1.00, green: 0.23, blue: 0.35)
        public static let success = Color(red: 0.20, green: 0.85, blue: 0.44)
        public static let warning = Color(red: 1.00, green: 0.72, blue: 0.15)

        /// Live-audio ramp, painted bottom → top so louder bars reach cyan.
        public static let waveform = LinearGradient(
            colors: [coral, violet, cyan],
            startPoint: .bottom,
            endPoint: .top
        )

        /// Processing ramp, painted leading → trailing to read as motion.
        public static let processing = LinearGradient(
            colors: [cyan, violet, coral],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Motion

    /// Animation curves. Every curve collapses to `nil` when the user has asked
    /// for reduced motion, so a single opt-out silences the whole interface.
    public enum Motion {
        @MainActor
        public static var isReduced: Bool {
            SettingsManager.shared.settings.reduceMotion
                || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }

        /// State changes on the floating bar (size, content swaps).
        @MainActor
        public static var bar: Animation? {
            isReduced ? nil : .spring(response: 0.34, dampingFraction: 0.82)
        }

        /// Fast, level-driven motion such as waveform bars.
        @MainActor
        public static var reactive: Animation? {
            isReduced ? nil : .spring(response: 0.20, dampingFraction: 0.62)
        }

        /// Onboarding and settings transitions.
        @MainActor
        public static var page: Animation? {
            isReduced ? nil : .easeInOut(duration: 0.22)
        }

        /// Ambient loops (pulsing dot, shimmering placeholder bars).
        @MainActor
        public static func ambient(_ duration: Double, autoreverses: Bool = true) -> Animation? {
            isReduced ? nil : .easeInOut(duration: duration).repeatForever(autoreverses: autoreverses)
        }
    }

    // MARK: - Typography

    public enum Font {
        public static func barTitle(_ compact: Bool) -> SwiftUI.Font {
            .system(size: compact ? 11.5 : 12.5, weight: .semibold, design: .rounded)
        }

        public static func barCaption(_ compact: Bool) -> SwiftUI.Font {
            .system(size: compact ? 9 : 10, weight: .medium, design: .rounded)
        }

        public static func barBadge(_ compact: Bool) -> SwiftUI.Font {
            .system(size: compact ? 8.5 : 9.5, weight: .bold, design: .rounded)
        }

        public static let paneTitle = SwiftUI.Font.system(size: 20, weight: .bold)
        public static let paneSubtitle = SwiftUI.Font.system(size: 12, weight: .regular)
        public static let cardTitle = SwiftUI.Font.system(size: 12, weight: .semibold)
        public static let rowTitle = SwiftUI.Font.system(size: 13, weight: .regular)
        public static let rowDetail = SwiftUI.Font.system(size: 11, weight: .regular)
        public static let monoKey = SwiftUI.Font.system(size: 11, weight: .semibold, design: .rounded)
    }
}
