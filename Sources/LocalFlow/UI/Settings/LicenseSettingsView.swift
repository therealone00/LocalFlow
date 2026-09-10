import SwiftUI
import AppKit

public struct LicenseSettingsView: View {
    @ObservedObject var licenseManager = LicenseManager.shared

    @State private var keyInput = ""
    @State private var errorMessage: String?
    @State private var justActivated = false
    @State private var isConfirmingRemoval = false

    public init() {}

    public var body: some View {
        SettingsPane(
            title: licenseManager.isPro ? "LocalFlow Pro" : "Upgrade to Pro",
            subtitle: licenseManager.isPro
                ? "Thanks for buying. Everything is unlocked on this Mac."
                : "A one-time purchase. No subscription, no account, no activation server.",
            systemImage: licenseManager.isPro ? "checkmark.seal.fill" : "sparkles.square.filled.on.square"
        ) {
            if let license = licenseManager.license {
                activeLicenseCard(license)
            } else {
                purchaseCard
                activationCard
            }

            SettingsCard("What Pro includes") {
                ForEach(ProFeature.allCases) { feature in
                    HStack(alignment: .top, spacing: DS.Spacing.m) {
                        Image(systemName: licenseManager.isPro ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                            .foregroundStyle(licenseManager.isPro ? DS.Palette.success : Color.secondary.opacity(0.45))
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: DS.Spacing.hair) {
                            Text(feature.title)
                                .font(DS.Font.rowTitle)
                            Text(feature.summary)
                                .font(DS.Font.rowDetail)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }

            SettingsCard(
                "The honest version",
                footnote: "Lost your key? It is in your purchase confirmation email, and can be recovered from the website with your order number."
            ) {
                Text("LocalFlow's source is public. You could compile a build without this check in an afternoon, and nothing stops you. Pro exists because the app is maintained by one person, and buying it is what keeps that happening.")
                    .font(DS.Font.rowDetail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Active

    private func activeLicenseCard(_ license: License) -> some View {
        SettingsCard("Your license") {
            HStack(alignment: .center, spacing: DS.Spacing.l) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(DS.Palette.success)

                VStack(alignment: .leading, spacing: DS.Spacing.hair) {
                    Text("Pro is active")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Issued to \(license.maskedEmail) on \(license.issueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            SettingRow("Order", detail: "Quote this if you ever need support.") {
                Text(license.orderId)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            SettingRow(
                "Using another Mac?",
                detail: "The same key works on every Mac you own. Removing it here does not cancel anything."
            ) {
                Button("Remove from this Mac", role: .destructive) {
                    isConfirmingRemoval = true
                }
                .controlSize(.small)
            }
        }
        .confirmationDialog("Remove the license from this Mac?", isPresented: $isConfirmingRemoval) {
            Button("Remove", role: .destructive) {
                licenseManager.deactivate()
                keyInput = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can paste the same key back in at any time.")
        }
    }

    // MARK: - Purchase

    private var purchaseCard: some View {
        SettingsCard {
            HStack(alignment: .center, spacing: DS.Spacing.l) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                        Text(AppConstants.proPrice)
                            .font(.system(size: 32, weight: .bold))
                        Text("once")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Text("Yours for good, on every Mac you own. Free updates.")
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                UpgradeButton()
                    .controlSize(.large)
            }
        }
    }

    private var activationCard: some View {
        SettingsCard(
            "Already bought it?",
            footnote: "Verified on this Mac against a key built into the app. Nothing is sent anywhere."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                HStack(spacing: DS.Spacing.s) {
                    TextField("LF1.…", text: $keyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit(activate)

                    Button("Paste") {
                        if let clip = NSPasteboard.general.string(forType: .string) {
                            keyInput = clip
                            activate()
                        }
                    }
                    .controlSize(.small)

                    Button("Activate", action: activate)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(DS.Palette.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if justActivated {
                    Label("Activated. Everything is unlocked.", systemImage: "checkmark.circle.fill")
                        .font(DS.Font.rowDetail)
                        .foregroundStyle(DS.Palette.success)
                }
            }
        }
    }

    private func activate() {
        switch licenseManager.activate(key: keyInput) {
        case .success:
            errorMessage = nil
            justActivated = true
            keyInput = ""
        case .failure(let error):
            errorMessage = error.message
            justActivated = false
        }
    }
}
