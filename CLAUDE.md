# CLAUDE.md

Working notes for LocalFlow. Read this before changing anything.

## What this is

A macOS menu bar agent for dictation. Hold a key, talk, and the transcript is
cleaned up and typed at the cursor of whatever app has focus. WhisperKit on the
Apple Neural Engine; everything runs on-device.

Free is a complete app. Pro is a €15 one-time purchase.

## The one rule

**Nothing leaves the user's Mac.** No telemetry, no crash reporting, no
analytics, no cloud inference — not behind a flag, not opt-in. The only network
access in the whole codebase is the explicit, user-initiated model download.

The Pro license check follows the same rule: keys are Ed25519 signatures
verified locally against a public key compiled into the app. There is no
activation server, and adding one would break the product's only promise.

## Layout

```
Sources/LocalFlow/
  App/            AppDelegate (menu bar, windows), AppState (dictation state machine)
  Audio/          capture, device selection, VAD
  Transcription/  WhisperKit + whisper.cpp behind TranscriptionEngine
  Intelligence/   rule-based cleanup, optional local LLM polish
  Accessibility/  reading cursor context, typing into other apps
  Licensing/      offline license verification and entitlements
  UI/
    DesignSystem/ DS tokens + shared components. Start here for any UI work.
    FloatingBar/   the bar shown while dictating
    Settings/      nine panes
    Onboarding/
docs/             the GitHub Pages site (index, success, impressum)
server/           Cloudflare Worker: Stripe checkout + license issuing
scripts/          build_app.sh, create_dmg.sh
```

## Conventions that are not obvious

**Design tokens.** Every spacing value, radius, colour and animation curve comes
from `DS` in `UI/DesignSystem/`. Add a token rather than a magic number.
Animations go through `DS.Motion` so reduced motion silences them from one place.

**A preference that is rendered must be read.** Version 1.1 existed largely
because six settings were displayed and never consulted by any code. If you add
a toggle, wire it in the same change.

**Enum `rawValue`s are persistence keys, not labels.** They are what gets
encoded into UserDefaults. User-facing text lives in
`Models/SettingsDisplay.swift`. Renaming a rawValue silently resets every user's
settings, because a decode failure falls back to defaults.

**Entitlements resolve in one place.** The pipeline reads
`SettingsManager.effectiveSettings`, which downgrades Pro-only choices for the
free tier. Do not scatter `isPro` checks through the engines. A stored Pro
preference is left untouched so buying restores it rather than resetting it.

**Free limits hide data, they never delete it.** History keeps storing 100
transcripts and surfaces 25; the dictionary keeps every existing rule working
and only blocks new ones past 10. Someone who buys Pro must get their data back
intact, not discover it was thrown away.

**Don't ship a control that does not work.** "Custom Shortcut" once bound a bare
keycode with no modifier check, so selecting it made the space bar start
dictation system-wide. It is hidden from the pickers and resolves to Hold Fn.

## Build

```bash
swift build && swift test      # 19 tests
./scripts/build_app.sh         # build/LocalFlow.app
./scripts/create_dmg.sh        # builds the app first, then the DMG
```

`create_dmg.sh` reads the version from `Config/Info.plist` — the single source
of truth. `AppConstants.appVersion` reads it back from the bundle. To release:
bump Info.plist, run `create_dmg.sh`, then `gh release create` with both
`LocalFlow.dmg` (stable permalink name) and `LocalFlow-vX.Y.Z.dmg`.

**The stable name matters.** `releases/latest/download/LocalFlow.dmg` requires
an exact asset filename, so a versioned-only asset breaks every download button
on the site the moment a new version ships.

**Every published build must be notarized**, or Gatekeeper blocks it on any Mac
but this one:

```bash
./scripts/build_app.sh     # signs with Developer ID + hardened runtime
./scripts/notarize.sh      # submits and staples the app, then the DMG
```

`notarize.sh` refuses anything signed with the wrong certificate or missing the
hardened runtime. Credentials live in the login keychain under the profile
`LocalFlow` (`notarize.sh --setup` stores them). Never sign a release with the
Apple Development or Apple Distribution certificate — both exist in this
keychain and neither works for distribution.

## Licensing infrastructure

- `server/scripts/setup.sh` deploys the Worker end to end; there is a
  double-clickable `.command` wrapper next to it.
- `server/.signing-key.json` is gitignored and **irreplaceable**. Losing it
  invalidates every license ever sold. It must match
  `LicenseVerifier.publicKeyBase64`; setup.sh refuses to run if it does not.
- Secrets live in Cloudflare's secret store, never in the repo. Never paste an
  API key into a chat, a file or a commit.
- The seller is a Kleinunternehmer under § 19 UStG, so `automatic_tax` is off in
  `server/src/stripe.js`. Do not turn it back on without checking that status.
- Worker behaviour is covered by a Node harness that stubs Stripe and KV; run it
  before touching `server/src/`.

## Licence

Elastic License 2.0 from 1.2.0 onwards. Source stays readable, forkable and
modifiable; removing the license key check or reselling LocalFlow as a hosted
service is not permitted. **1.0.0 and 1.1.0 remain MIT forever** — that grant is
irrevocable. See `NOTICE.md`.

## Known gaps

- `.github/workflows/ci.yml` exists locally but has never been pushed: the
  GitHub token lacks the `workflow` scope. `gh auth refresh -s workflow` fixes it.
- No Widerrufsbelehrung or AGB on the site, which selling to EU consumers
  normally requires. Flagged, not written — that needs a lawyer, not a model.
- Intel Macs fall back to whisper.cpp and are much slower than the sub-second
  figures quoted publicly, which are Apple Silicon numbers.

## Tone

User-facing strings are English, plain, and specific. No exclamation marks, no
"seamless", no "powerful". Error messages say what to do next: "Paste the
license key from your purchase confirmation", not "Invalid license".
