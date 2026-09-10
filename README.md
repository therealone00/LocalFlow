<h1 align="center">LocalFlow</h1>

<p align="center">
  <strong>On-device dictation for macOS — powered by the Apple Neural Engine</strong><br>
  <em>Hold a key, talk, and your words are typed into whatever app you are in. Nothing leaves your Mac.</em>
</p>

<p align="center">
  <a href="https://github.com/therealone00/LocalFlow/releases/latest"><img src="https://img.shields.io/github/v/release/therealone00/LocalFlow?color=00D2FF&label=Release&style=flat-square" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-black?style=flat-square&logo=apple" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Apple%20Silicon-Neural%20Engine-black?style=flat-square" alt="Apple Silicon ANE">
  <img src="https://img.shields.io/badge/Privacy-100%25%20On--Device-34C759?style=flat-square" alt="100% On-Device">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Elastic%202.0-blue?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="#download">Download</a> •
  <a href="#free--pro">Pricing</a> •
  <a href="#features">Features</a> •
  <a href="#how-it-works">How it works</a> •
  <a href="https://therealone00.github.io/LocalFlow/">Website</a>
</p>

---

## Overview

LocalFlow gives you system-wide voice input on macOS under one strict rule:

> **All audio capture, inference and text cleanup happen on your Mac.**
> No cloud transcription. No external APIs. No account. Zero data egress.

Hold your hotkey, speak, release. Audio goes to WhisperKit on the Apple Neural
Engine, the transcript is cleaned up, and the result is typed at your cursor —
usually in under a second.

---

## Free & Pro

Free is a complete dictation app. Not a trial, not time-limited, no nag screens.

| | Free | Pro — €15 once |
| :--- | :---: | :---: |
| Dictation | Unlimited | Unlimited |
| Rule-based cleanup | ✓ | ✓ |
| Speech models | Tiny, Base | + **Small** |
| Dictionary rules | 10 | Unlimited |
| History in reach | Last 25 | All of it |
| Smart AI polish (local LLM) | — | ✓ |
| Per-app writing styles | — | ✓ |

One payment, every Mac you own, all future updates included.

**The license key is verified offline** — an Ed25519 signature checked against a
public key compiled into the app. LocalFlow never contacts a server to confirm
you paid, so Pro keeps working with no network at all.

Buy it on [the website](https://therealone00.github.io/LocalFlow/#pricing), then
paste the key into Settings › Pro.

---

## Download

1. Download **[LocalFlow.dmg](https://github.com/therealone00/LocalFlow/releases/latest/download/LocalFlow.dmg)** — this link always points at the newest release.
2. Open it and drag **LocalFlow.app** into **Applications**.
3. Launch it. Builds are signed with a Developer ID certificate and notarised by Apple, so it opens normally — no Gatekeeper warning and no right-click trick.
4. Grant the two permissions the setup guide asks for:
   - **Microphone** — to hear you. Audio never touches the disk.
   - **Accessibility** — to type into the app you are focused on.

The setup guide continues by itself once each permission is granted.

### Build it yourself

```bash
git clone https://github.com/therealone00/LocalFlow.git
cd LocalFlow
./scripts/build_app.sh
open build/LocalFlow.app
```

Requires macOS 14+ and a Swift 6 toolchain. Nothing else — WhisperKit is
resolved by SwiftPM.

---

## Features

- **Types where your cursor is.** Inserts through the macOS Accessibility APIs, so it works in Safari, Chrome, Slack, VS Code, Notes, Xcode, Terminal and everything else.
- **Neural Engine inference.** WhisperKit via CoreML on Apple Silicon, ~0.7s for a normal sentence. Intel Macs fall back to whisper.cpp and are noticeably slower.
- **A floating bar that stays out of the way.** Sizes itself to its content, appears on the display under your pointer, shows elapsed recording time, and passes clicks through to the app underneath unless it is offering a control. The meter draws a rolling history of real microphone levels rather than a decorative animation.
- **Push-to-talk and hands-free.** Hold `fn` or right `⌥` and release to insert. Double-press for hands-free, which ends on its own after your silence threshold. `Esc` throws a dictation away.
- **Cleanup you control.** Filler words, spoken self-corrections (*"morgen um 14, nein um 15 Uhr" → "morgen um 15 Uhr"*), punctuation and capitalisation — each rule switchable on its own.
- **Local history and dictionary.** Search everything you have dictated and re-insert it. Teach LocalFlow the names and jargon it should always spell your way.
- **Zero data retention.** Audio exists in memory for one transcription and is then released. There is no setting to change that because there is no code path that writes it.
- **Accessible by default.** Honours Reduce Motion, both the app's own setting and the macOS one.

---

## How it works

```
[ Microphone ]
      │  16 kHz Float32, lock-protected ring buffer
      ▼
[ Voice Activity Detector ]
      │  energy-adaptive silence detection
      ▼
[ WhisperKit ] ──► Apple Neural Engine / CoreML
      │  ~0.7s, on-device
      ▼
[ Text cleanup ]
      │  filler words → self-corrections → punctuation → dictionary
      ▼
[ Accessibility insertion ] ──► your cursor
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the reasoning behind each stage.

---

## Comparison

| | LocalFlow | Wispr Flow | Superwhisper | macOS Dictation |
| :--- | :---: | :---: | :---: | :---: |
| **Where inference runs** | **On-device (ANE)** | Cloud servers | Local / hybrid | Hybrid |
| **Cost** | **Free, €15 once for Pro** | $12–15 / mo | $8 / mo | Included |
| **Audio uploaded** | **None (0 bytes)** | Yes | Depends on mode | Partly |
| **Works offline** | **Always** | No | Depends on mode | Partly |
| **Account required** | **No** | Yes | Yes | Apple ID |
| **Source readable** | **Yes** | No | No | No |
| **Self-correction handling** | Local parser | Cloud LLM | Pro tier only | None |

---

## Contributing

Pull requests are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) has the build
steps and the one hard rule: nothing leaves the user's Mac.

Found a security issue? Report it privately — see [SECURITY.md](SECURITY.md).

---

## License

**[Elastic License 2.0](LICENSE)** © 2026 loomlytic.

Read it, fork it, modify it, build your own copy — all explicitly allowed. What
is not allowed is removing the license key check or reselling LocalFlow as a
hosted service.

Versions 1.0.0 and 1.1.0 were released under MIT and stay MIT forever. See
[NOTICE.md](NOTICE.md) for the full history.
