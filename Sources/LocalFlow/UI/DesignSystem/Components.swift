import SwiftUI
import AppKit

// MARK: - Settings pane scaffold

/// Standard scaffold for a settings pane: a titled header with an icon and a
/// one-line explanation, followed by scrollable content.
public struct SettingsPane<Content: View>: View {
    private let title: String
    private let subtitle: String
    private let systemImage: String
    private let content: () -> Content

    public init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                HStack(alignment: .center, spacing: DS.Spacing.m) {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(DS.Font.paneTitle)
                        Text(subtitle)
                            .font(DS.Font.paneSubtitle)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, DS.Spacing.xs)

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.xl)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Card

/// A titled group of related settings.
public struct SettingsCard<Content: View>: View {
    private let title: String?
    private let footnote: String?
    private let content: () -> Content

    public init(
        _ title: String? = nil,
        footnote: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.footnote = footnote
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            if let title {
                Text(title.uppercased())
                    .font(DS.Font.cardTitle)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DS.Spacing.xs)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                content()
            }
            .padding(DS.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            )

            if let footnote {
                Text(footnote)
                    .font(DS.Font.rowDetail)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DS.Spacing.xs)
            }
        }
    }
}

// MARK: - Rows

/// A labelled row with an optional explanation and a trailing control.
public struct SettingRow<Control: View>: View {
    private let title: String
    private let detail: String?
    private let control: () -> Control

    public init(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.title = title
        self.detail = detail
        self.control = control
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: DS.Spacing.hair) {
                Text(title)
                    .font(DS.Font.rowTitle)
                if let detail {
                    Text(detail)
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DS.Spacing.m)
            control()
                .labelsHidden()
        }
    }
}

/// A toggle row with an explanation underneath the label.
public struct SettingToggle: View {
    private let title: String
    private let detail: String?
    @Binding private var isOn: Bool

    public init(_ title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    public var body: some View {
        SettingRow(title, detail: detail) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

// MARK: - Status chip

public struct StatusChip: View {
    public enum Kind {
        case positive, neutral, warning

        var tint: Color {
            switch self {
            case .positive: return DS.Palette.success
            case .neutral: return .secondary
            case .warning: return DS.Palette.warning
            }
        }
    }

    private let text: String
    private let kind: Kind
    private let systemImage: String?

    public init(_ text: String, kind: Kind = .neutral, systemImage: String? = nil) {
        self.text = text
        self.kind = kind
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.3)
        }
        .foregroundStyle(kind.tint)
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, 3)
        .background(kind.tint.opacity(0.14), in: Capsule())
    }
}

// MARK: - Keycap

/// Renders a shortcut as macOS-style keycaps, e.g. `⌥` + `Space`.
public struct KeycapView: View {
    private let keys: [String]

    public init(keys: [String]) {
        self.keys = keys
    }

    public init(shortcut: ShortcutMode, customKeyName: String = "Space") {
        self.keys = shortcut.keycaps(customKeyName: customKeyName)
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(DS.Font.monoKey)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                            .fill(Color(nsColor: .controlColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Permission row

/// A permission with live status and a one-click way to grant it.
public struct PermissionRow: View {
    private let title: String
    private let detail: String
    private let systemImage: String
    private let isGranted: Bool
    private let action: () -> Void

    public init(
        title: String,
        detail: String,
        systemImage: String,
        isGranted: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.isGranted = isGranted
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            ZStack {
                Circle()
                    .fill((isGranted ? DS.Palette.success : DS.Palette.warning).opacity(0.16))
                    .frame(width: 30, height: 30)
                Image(systemName: isGranted ? "checkmark" : systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isGranted ? DS.Palette.success : DS.Palette.warning)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.hair) {
                Text(title)
                    .font(DS.Font.rowTitle)
                Text(isGranted ? "Granted" : detail)
                    .font(DS.Font.rowDetail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DS.Spacing.m)

            if isGranted {
                StatusChip("ACTIVE", kind: .positive)
            } else {
                Button("Grant…", action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}
