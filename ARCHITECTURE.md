# LocalFlow Architecture & Technical Decisions

This document outlines the architectural patterns, API selections, performance optimizations, and security guarantees behind LocalFlow.

---

## 1. Why Native Swift & SwiftUI / AppKit

LocalFlow is strictly engineered as a 100% native macOS application:
- **Zero Electron / WebKit Overhead**: An AI dictation tool that sits in the background must consume minimal RAM (< 80 MB idle) and zero CPU cycles when idle.
- **Low-Latency Event Delivery**: Intercepting keypresses and streaming audio buffers at 60–120 Hz requires direct access to CoreAudio, CoreGraphics, and AppKit run loops.
- **Focus Preservation**: Web-based wrappers frequently trigger window activation cycles that steal keyboard focus. LocalFlow uses an `NSPanel` with `.nonactivatingPanel` and `canBecomeKey = false` to guarantee the user's active editor or browser never loses focus.

---

## 2. Speech-to-Text: WhisperKit vs whisper.cpp

To provide an optimal universal experience across both modern Apple Silicon and legacy Intel Macs:

### WhisperKit (Primary on Apple Silicon)
- **Engine**: CoreML execution using Apple's Neural Engine (ANE) and Metal GPU.
- **Models**: `openai_whisper-base` (multilingual), `tiny`, `small`.
- **Latency**: Sub-second execution for standard phrases due to 16-bit float quantization and ANE kernel compilation.
- **Standard**: `openai_whisper-base` is the default because it reliably supports German and English code-switching.

### whisper.cpp (Fallback for Intel & Universal Systems)
- **Engine**: Highly optimized C++ GGML runtime with AVX2/AVX-512 acceleration on x86_64 and optional Metal support.
- **Modular Isolation**: Both engines conform to the identical `TranscriptionEngine` protocol:
  ```swift
  public protocol TranscriptionEngine: Sendable {
      var engineType: TranscriptionEngineType { get }
      var isPrepared: Bool { get }
      func prepare() async throws
      func transcribe(audioSamples: [Float], language: String?) async throws -> TranscriptionResult
      func cancel()
      func unload() async
  }
  ```

---

## 3. Audio Pipeline

- **Framework**: `AVAudioEngine` with `inputNode`.
- **Target Format**: 16,000 Hz, 1 channel (Mono), Float32.
- **Resampling**: `AVAudioConverter` seamlessly converts from device hardware rates (44.1 kHz, 48 kHz stereo) to the single-channel 16 kHz Float32 format expected by Whisper.
- **Thread-Safety**: The CoreAudio tap runs on a realtime thread, so samples are appended to a `SynchronizedAudioBuffer` guarded by an `os_unfair_lock` rather than an actor — awaiting an actor from that thread would risk audio dropouts.
- **Metering**: RMS calculation is computed on each frame using Apple's `Accelerate` framework (`vDSP_rmsqv`), publishing normalized 0.0–1.0 values to drive the UI waveform animation at 60 Hz.
- **Zero Disk Leakage**: Audio data is held exclusively in volatile RAM and completely cleared upon session completion.

---

## 4. Hotkey System & CGEventTap Resilience

- **Mechanism**: A system-level `CGEventTap` placed at `.headInsertEvent` capturing `.flagsChanged`, `.keyDown`, and `.keyUp`.
- **Zero Heavy Work in Callback**: The C callback executes in under 0.05ms: it merely checks modifier bitmasks (`.maskSecondaryFn` for the Fn/Globe key) and posts actions to the MainActor queue.
- **System Timeout Recovery**: macOS can disable event taps if the system experiences a momentary hiccup. LocalFlow explicitly handles `.tapDisabledByTimeout` and `.tapDisabledByUserInput` by calling `CGEventTapEnable(machPort, true)`.
- **Double-Tap Hands-Free**: A time difference threshold (< 350ms) between consecutive Fn key depressions triggers hands-free mode.
- **Esc-Key Cancellation**: Pressing Escape while recording instantly cancels the audio capture and dismisses the floating bar.

---

## 5. Text Injection Subsystem

Text insertion occurs without stealing window or keyboard focus:

```
                  +---------------------------+
                  | Raw Audio -> Cleaned Text |
                  +-------------+-------------+
                                |
                                v
              +----------------------------------+
              | FocusedElementReader             |
              | (Check AX and Password Fields)   |
              +-----------------+----------------+
                                |
             +------------------+------------------+
             |                                     |
             v                                     v
+------------------------+             +------------------------+
| Strategy 1: Direct AX  |             | Strategy 2: Universal  |
| kAXSelectedTextAttribute|             | Clipboard Fallback     |
+------------+-----------+             +-----------+------------+
             | Success?                            |
       Yes --+-- No -------------------------------+
             |                                     |
             v                                     v
+------------------------+             +------------------------+
| Text Inserted Directly |             | 1. Backup Pasteboard   |
+------------------------+             | 2. Set Dictated Text   |
                                       | 3. Synthesize Cmd+V    |
                                       | 4. Delay 80ms          |
                                       | 5. Restore Pasteboard  |
                                       +------------------------+
```

---

## 6. Multi-Stage Text Cleanup Pipeline

Raw automatic speech recognition (ASR) output contains hesitation sounds, retracted statements, and unformatted punctuation. LocalFlow resolves this through a three-stage pipeline:

1. **Stage 1: Rule-Based Cleaner (`RuleBasedCleaner`)**
   - **Filler Elimination**: Context-safe regex for German (`äh`, `ähm`, `hm`, `also`) and English (`uh`, `um`, `erm`).
   - **Self-Corrections / Backtracks**: Identifies retracting patterns (`"morgen, nee Donnerstag"` ➔ `"Donnerstag"`, `"Peter, ach nein, an Max"` ➔ `"an Max"`).
   - **Spoken Punctuation**: Converts verbal commands (`"Punkt"`, `"Komma"`, `"Fragezeichen"`, `"neue Zeile"`, `"neuer Absatz"`).
   - **Spoken Lists**: Formats enumerated lists (`"erstens ... zweitens ..."` ➔ `1. ...\n2. ...`).
   - **Spacing & Capitalization**: Normalizes spaces around punctuation marks and capitalizes sentence beginnings.
2. **Stage 2: Personal Dictionary (`DictionaryManager`)**
   - User-defined phonetic substitutions (e.g. `"local flow"` ➔ `"LocalFlow"`, `"Swift UI"` ➔ `"SwiftUI"`).
3. **Stage 3: Optional Local LLM Cleaner (`LocalLLMCleaner`)**
   - When the user selects the `Smart` tier, a small local model (e.g. Qwen2.5-Instruct via `llama.cpp`) processes the text with an ultra-restrictive system prompt.
   - Temperature is set to `0.1` and thinking modes are disabled to prevent hallucinations or conversational answers.

---

## 7. Security, Privacy & App Sandbox

- **Zero Cloud Guarantee**: Transcriptions, audio buffers, and text cleanup occur strictly on device.
- **Secure Text Fields**: If `FocusedElementReader` detects an `AXSecureTextField` or password field, context reading is suppressed.
- **No Background Audio Eavesdropping**: The microphone is only energized while the hotkey is depressed (or during active hands-free mode).
- **Modern Launch at Login**: Uses Apple's `SMAppService.mainApp.register()` without deprecated helper bundles or legacy scripts.

---

## 8. UI Layer & Design Tokens

Every spacing value, radius, colour and animation curve lives in `DS`
(`UI/DesignSystem/`). This is not cosmetic tidiness — it is what makes a single
Reduce Motion switch silence the whole interface, because every animation is
constructed through `DS.Motion` and each curve collapses to `nil` when motion is
reduced (the app's own setting *or* the macOS one).

Two rules the codebase enforces:

- **A preference that is rendered must be read.** Version 1.1 existed largely
  because six settings were displayed and consulted by nothing.
- **Enum `rawValue`s are persistence keys, not labels.** They are what gets
  encoded into `UserDefaults`; renaming one silently resets every user's
  settings, because a decode failure falls back to defaults. User-facing text
  lives in `Models/SettingsDisplay.swift`.

The floating bar is an `NSPanel` that measures the ideal size of its SwiftUI
content and resizes to match, instead of picking a width per state. It appears
on the screen under the pointer rather than the primary display, and sets
`ignoresMouseEvents` unless it is actually showing a control, so it never
swallows a click meant for the app underneath.

---

## 9. Licensing

LocalFlow has a paid tier, and the licensing design is constrained by the same
guarantee as everything else: it must work with no network.

- **Offline verification.** A key is `LF1.<payload>.<signature>`, an Ed25519
  signature over the payload, checked against a public key compiled into the
  app. The signature is verified *before* the payload is decoded, so untrusted
  bytes are never parsed. There is no activation server and no phone-home.
- **Entitlements resolve in one place.** The pipeline reads
  `SettingsManager.effectiveSettings`, which downgrades Pro-only choices on the
  free tier. Engines contain no `isPro` checks. The user's stored preference is
  never overwritten, so buying Pro restores what they had picked.
- **Free limits hide data, they never delete it.** History keeps storing 100
  transcripts and surfaces 25; the dictionary keeps every existing rule working
  and only blocks new ones past the ceiling. Upgrading must return someone's
  data intact, not reveal that it was discarded.
- **Issuing lives outside the app.** A Cloudflare Worker (`server/`) creates
  Stripe Checkout sessions, verifies webhook signatures with a timing-safe
  comparison and a replay window, and signs licenses idempotently — Stripe
  delivers webhooks at least once, so issuing must be safe to run twice.

The signing key is the one irreplaceable artefact in the project: losing it
invalidates every license ever sold.
