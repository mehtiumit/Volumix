# Roadmap

Each phase must leave a working application. A phase is complete only when its exit criteria pass.

## Phase 0 — Foundation and measurement

- [x] SwiftPM package, Makefile, Info.plist, and `.app` packaging.
- [x] Menu bar application with no Dock icon.
- [x] CLI spike that discovers processes, creates a tap and aggregate device, and applies gain.
- [x] Document measured answers to the initial CoreAudio questions.

Exit criterion: a terminal-run tool reliably reduces a target application's audio level.

## Phase 1 — Core mixer

- [x] Live discovery of audio-producing applications.
- [x] One aggregate device per output device.
- [x] Real-time-safe gain application with smoothing.
- [x] Popover UI with per-application volume and mute controls.
- [x] Tap cleanup when applications stop and during process termination.

Exit criterion: multiple applications can use independent gains and return to normal after exit.

## Phase 2 — Live level meter

- [x] Per-block RMS measurement in the IOProc.
- [x] 30 Hz UI sampling with attack and release smoothing.
- [x] Integrated PulseTrack visualization.

Exit criterion: meters remain responsive without a meaningful CPU increase.

## Phase 3 — Persistence and shortcuts

- [x] Persist gain, mute, and output choice by bundle identifier.
- [x] Restore settings when an application resumes playback.
- [x] Global `⌥⌘V` shortcut.
- [x] Launch at login with `SMAppService`.

## Phase 4 — Per-application output routing

- [x] Discover output devices and observe default-device changes.
- [x] Output selector in each application row.
- [x] Move taps between output-specific mixer engines.
- [x] Fall back to the default output when a selected device is removed.

Risk: devices with incompatible sample rates may require aggregate-device resampling behavior that
varies by hardware. If a device combination cannot be supported safely, show a warning and fall
back to the system default.

## Phase 5 — Open-source distribution

- [x] English source comments, diagnostics, UI strings, and documentation.
- [x] Contributor, security, conduct, and AI coding-agent guidance.
- [x] Build, troubleshooting, and release documentation.
- [ ] Final application and menu bar artwork.
- [ ] Automated build verification on GitHub Actions.
- [ ] Developer ID signing and Apple notarization.
- [ ] Versioned release archive or DMG.

## Out of scope for v1

- EQ, compression, and audio effects.
- Per-application microphone control.
- Audio recording or export.
- Preservation of 5.1 or Atmos channel layouts.
- Support for macOS releases before 14.4, which would require a virtual audio driver.
