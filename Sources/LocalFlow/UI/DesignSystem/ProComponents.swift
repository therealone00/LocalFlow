import SwiftUI
import AppKit

/// Small "PRO" marker for anything the free tier does not include.
public struct ProBadge: View {
    public init() {}

    public var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .heavy))
            .kerning(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [DS.Palette.violet, DS.Palette.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .accessibilityLabel("Pro feature")
    }
}

/// A row describing a locked feature, with the one action that unlocks it.
public struct ProUpsellRow: View {
    private let feature: ProFeature
    private let compact: Bool

    public init(_ feature: ProFeature, compact: Bool = false) {
        self.feature = feature
        self.compact = compact
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Palette.violet)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: DS.Spacing.hair) {
                HStack(spacing: DS.Spacing.s) {
                    Text(feature.title)
                        .font(DS.Font.rowTitle)
                    ProBadge()
                }
                if !compact {
                    Text(feature.summary)
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: DS.Spacing.m)

            UpgradeButton()
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                .fill(DS.Palette.violet.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                .strokeBorder(DS.Palette.violet.opacity(0.22), lineWidth: 1)
        )
    }
}

/// Opens the pricing page. One-time purchase, so the label says so — "Upgrade"
/// alone reads like a subscription.
public struct UpgradeButton: View {
    private let prominent: Bool

    public init(prominent: Bool = true) {
        self.prominent = prominent
    }

    public var body: some View {
        Button {
            NSWorkspace.shared.open(AppConstants.purchaseURL)
        } label: {
            Text("Get Pro — \(AppConstants.proPrice) once")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .help("Opens the LocalFlow website")
    }
}
