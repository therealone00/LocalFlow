<p align="center">
  <img src="assets/hero.jpg" alt="LocalFlow Banner" width="100%" style="border-radius: 8px;" />
</p>

<h1 align="center">LocalFlow</h1>

<p align="center">
  <strong>100% Offline, Native macOS Speech-to-Text — Powered by Apple Neural Engine & WhisperKit</strong><br>
  <em>System-wide voice input. Sub-0.8s on-device inference. Zero cloud dependencies. Zero subscriptions.</em>
</p>

<p align="center">
  <a href="https://github.com/therealone00/LocalFlow/releases/latest"><img src="https://img.shields.io/github/v/release/therealone00/LocalFlow?color=00D2FF&label=Release&style=flat-square" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-black?style=flat-square&logo=apple" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Apple%20Silicon-Neural%20Engine-black?style=flat-square" alt="Apple Silicon ANE">
  <img src="https://img.shields.io/badge/Privacy-100%25%20On--Device-34C759?style=flat-square" alt="100% On-Device">
  <a href="https://github.com/sponsors/therealone00"><img src="https://img.shields.io/badge/Sponsor-therealone00-24292F?style=flat-square&logo=github" alt="Sponsor"></a>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="#-download--installation"><strong>Download DMG</strong></a> •
  <a href="#-features"><strong>Features</strong></a> •
  <a href="#-architecture"><strong>Architecture</strong></a> •
  <a href="#-comparison"><strong>Comparison</strong></a> •
  <a href="#-support--sponsorship"><strong>Sponsor</strong></a> •
  <a href="https://therealone00.github.io/LocalFlow/"><strong>Website</strong></a>
</p>

---

## Overview

LocalFlow provides frictionless, system-wide speech dictation across macOS with a strict design requirement:

> **All audio processing, feature extraction, neural inference, and text polishing run entirely on-device.**
> No cloud transcription. No external APIs. Zero data egress. No user accounts. No subscription walls.

Holding your configured hotkey triggers real-time audio capture, routes 16kHz audio buffers to WhisperKit on the Apple Neural Engine, runs deterministic text cleanup, and writes directly into your focused cursor position in **under 0.8 seconds**.

---

## Download & Installation

### Direct DMG Download (Recommended)

1. Download **[LocalFlow-v1.0.0.dmg](https://github.com/therealone00/LocalFlow/releases/latest/download/LocalFlow-v1.0.0.dmg)**.
2. Open the disk image and drag **LocalFlow.app** into your **Applications** folder.
3. Launch LocalFlow from Applications or Spotlight (`Cmd + Space`).
4. Grant the standard macOS permissions:
   - **Microphone**: Local audio capture.
   - **Accessibility**: Required to inject text directly into third-party active fields.

### Build from Source

```bash
git clone https://github.com/therealone00/LocalFlow.git
cd LocalFlow
./scripts/build_app.sh
open build/LocalFlow.app
```

---

## Core Specifications

- **Universal Direct Text Injection**: Direct AX selected text injection or synchronized HID keyboard events into Safari, Chrome, Slack, VS Code, Notes, Xcode, Terminal, etc.
- **Apple Silicon Neural Engine Acceleration**: WhisperKit CoreML inference executes on the 16-core ANE in ~0.7s at 16x real-time factor.
- **Obsidian-Glass Floating Panel**: Minimalist `.ultraThinMaterial` panel with dynamic 7-bar vertical gradient equalizer and non-activating window level.
- **Push-to-Talk & Hands-Free Modes**:
  - Hold `Fn` (Globe) or `Right Option` to speak, release to commit.
  - Brief tap triggers hands-free mode; press `Return` or hotkey again to finish.
  - Also supports `Control + Option` and custom keybindings.
- **Deterministic Text Intelligence**:
  - Filters German & English conversational filler words (*„äh“, „ähm“, „quasi“, „sozusagen“, „like“*).
  - Spoken self-correction parser (*„morgen um 14, nein um 15 Uhr“ ➔ „morgen um 15 Uhr“*).
  - Contextual punctuation and capitalization.
- **Zero Data Retention**: Audio buffers exist solely in volatile RAM during recording and are purged immediately after transcription.

---

## Architecture

<p align="center">
  <img src="assets/architecture.jpg" alt="LocalFlow Architecture" width="100%" style="border-radius: 8px;" />
</p>

```
[ Microphone Input ] 
       │ 16kHz Float32 Ring Buffer (os_unfair_lock, Zero Jitter)
       ▼
[ Voice Activity Detector (VAD) ]
       │ Energy-adaptive silence detection
       ▼
[ WhisperKit Engine ] ──► Apple Neural Engine (ANE) / CoreML
       │ ~0.7s local inference
       ▼
[ Text Intelligence Pipeline ]
       │ 1. Filler Word Removal
       │ 2. Spoken Self-Correction Parser
       │ 3. Contextual Punctuation Engine
       ▼
[ Accessibility & Direct Injection ] ──► Focused macOS Cursor
```

---

## Technical Comparison

| Specification | LocalFlow | Wispr Flow | Superwhisper | macOS Dictation |
| :--- | :---: | :---: | :---: | :---: |
| **Inference Location** | **100% On-Device** | Cloud Server | Local / Hybrid | Hybrid |
| **Cost** | **$0 / MIT Open Source** | $12–$15 / mo | $8 / mo | Included |
| **Hardware Target** | **Apple Neural Engine** | Cloud GPU | Local CoreML | Standard |
| **Audio Egress** | **0 Bytes (RAM only)** | Uploaded | Mode-dependent | Partial |
| **Direct Text Insertion** | Universal | Universal | Universal | Basic |
| **Self-Correction Logic** | Local Parser | Cloud LLM | Pro tier only | None |
| **Filler Filtering** | German & English | Cloud LLM | Pro tier only | None |

---

## Support & Sponsorship

LocalFlow is developed independently as free, open-source software.

If LocalFlow accelerates your workflow, you can back ongoing maintenance, new language models, and future macOS compatibility through **[GitHub Sponsors](https://github.com/sponsors/therealone00)**:

<p align="center">
  <a href="https://github.com/sponsors/therealone00">
    <img src="https://img.shields.io/badge/Sponsor%20LocalFlow-GitHub%20Sponsors-24292F?style=for-the-badge&logo=github" alt="Sponsor on GitHub" height="38">
  </a>
</p>

Sponsorship support directly funds:
- Model fine-tuning and multilingual optimization.
- Maintenance across upcoming macOS operating system releases.
- Local on-device LLM integration via MLX / CoreML.

---

## License

MIT License © 2026 LocalFlow Contributors & [therealone00](https://github.com/therealone00).
