# Contributing to LocalFlow

Thanks for wanting to help. LocalFlow is a small, focused macOS app, and the
bar for a change is simply that it makes the app better for the person
dictating.

## Building

```bash
git clone https://github.com/therealone00/LocalFlow.git
cd LocalFlow
swift build          # debug build
swift test           # run the test suite
./scripts/build_app.sh   # produce build/LocalFlow.app
./scripts/create_dmg.sh  # produce build/LocalFlow-vX.Y.Z.dmg
```

Requirements: macOS 14 or later and a Swift 6 toolchain. There is nothing else
to install — WhisperKit is resolved by SwiftPM.

`build_app.sh` prefers a **Developer ID Application** certificate, signs with the
hardened runtime and a secure timestamp, and falls back to Apple Development or
ad-hoc signing with a loud warning. Only the Developer ID path produces
something another person can open.

Release builds are signed and notarized locally rather than in CI, because CI
has no access to the signing certificate:

```bash
./scripts/build_app.sh
./scripts/notarize.sh --setup   # once, stores credentials in your keychain
./scripts/notarize.sh           # submits and staples the app and the DMG
```

Notarization credentials live in the login keychain and never in the repo.

## Licensing

LocalFlow is under the [Elastic License 2.0](LICENSE) from 1.2.0 onwards. By
contributing you agree that your contribution is licensed the same way.

Two limits worth stating plainly, because they affect what a PR may do: the
license key functionality may not be removed, disabled or worked around, and
LocalFlow may not be offered to third parties as a hosted service. Everything
else — reading, forking, modifying, building your own copy — is fine.

## The one rule

**Nothing leaves the user's Mac.** No telemetry, no crash reporting, no
analytics, no cloud inference, not behind a flag and not opt-in. The only
network access in the codebase is the explicit, user-initiated model download.
A pull request that adds an outbound request anywhere else will not be merged.

## Working on the UI

- Every spacing value, radius, colour and animation curve comes from `DS` in
  `Sources/LocalFlow/UI/DesignSystem/`. Add a token rather than a magic number.
- Animations go through `DS.Motion` so that reduced motion silences them all
  from one place.
- A preference that is rendered must be read. If you add a toggle, wire it up in
  the same change — the 1.1 release existed largely to fix six that were not.
- Pro gating goes through `SettingsManager.effectiveSettings` and
  `LicenseManager.limit(for:)`, never an ad-hoc `isPro` check in a view that
  matters. A free-tier ceiling hides data, it never deletes it: a user who buys
  Pro must get their old history and dictionary rules back intact.
- Enum `rawValue`s are persistence keys, not labels. User-facing text belongs in
  `Models/SettingsDisplay.swift` so that renaming a label cannot reset anyone's
  settings.
- User-facing strings are English.

## Before opening a pull request

- `swift build` is clean, with no new warnings
- `swift test` passes
- You have run the app and used the surface you changed

Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `docs:`, `refactor:`, …), which is what the history already
uses.

## Reporting bugs

Use the issue templates. Please redact anything private from transcripts and
logs — a paraphrase reproduces most bugs just as well.
