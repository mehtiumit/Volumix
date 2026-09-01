# Architecture

## Decision summary

| Area | Decision | Rationale |
|---|---|---|
| Language | Swift 6 with direct CoreAudio C APIs | CoreAudio is already a C API; a C++ bridge adds no value. |
| UI | SwiftUI hosted in an AppKit popover | Native appearance, dark mode, and precise menu bar lifecycle control. |
| Capture | CoreAudio Process Tap on macOS 14.4+ | No virtual driver, installer, system extension, or elevated privileges. |
| Processing | IOProc on a private aggregate device | One callback and one mixing path with minimal latency. |
| Build | SwiftPM and Make | Works with Command Line Tools and avoids Xcode project maintenance. |
| Sandbox | Disabled for direct distribution | Process discovery and tap creation need capabilities that are constrained in the sandbox. |

## Audio signal path

Without Volumix, applications write to the system mixer and then to the output device:

```text
Spotify ─┐
Zoom    ─┼─→ [coreaudiod mixer] ─→ Output device ─→ Speakers
Safari  ─┘
```

For a tapped application, `.mutedWhenTapped` disconnects the original route. Volumix becomes
responsible for forwarding that audio:

```text
Spotify ──tap──┐
Zoom    ──tap──┼─→ [Private aggregate device] ──IOProc──→ Output device
Safari  ──tap──┘                 │                 × gain
                                 └─→ RMS ─→ UI meter
```

The aggregate device contains both a tap list for input and a physical subdevice for output. The
IOProc reads each tap buffer, applies its slot gain, mixes into the output buffers, and publishes
an RMS value for the UI.

## Output-based engine grouping

Volumix creates one `MixerEngine` per target output device, not per application. Each engine owns:

- One private aggregate device.
- One IOProc.
- The taps routed to its output.
- One independent `MixerSlots` table.

The normal case therefore uses one engine. Routing one application to headphones creates a second
engine for that output. This grouping makes per-application output routing a natural extension of
the same graph.

## Process discovery

`ProcessMonitor` reads:

```text
kAudioHardwarePropertyProcessObjectList → [AudioObjectID]
  kAudioProcessPropertyPID              → pid_t
  kAudioProcessPropertyBundleID         → String
  kAudioProcessPropertyIsRunningOutput  → Bool
```

The list is polled at 1 Hz. CoreAudio accepts listeners for the relevant properties and returns
`noErr`, but testing showed that it does not send notifications for playback-state changes. Polling
observed Spotify changing 1→0→1 across pause/play while the listener remained silent.

Two details prevent unnecessary graph rebuilds:

- Exclude Volumix's own PID because its IOProc also appears as an output-writing process.
- Compare sets of process IDs because CoreAudio does not guarantee list order.

System alert audio from `systemsoundserverd` deliberately bypasses Volumix. Screenshot and other
short system sounds toggle that process's output state; tapping it would recreate the aggregate
device when the sound starts and again when it ends, producing an audible interruption in existing
application audio. Leaving it on the original CoreAudio path keeps the mixer graph stable.

## Application identity

CoreAudio may report several helper processes for one application. `AppIdentity` resolves the
outermost `.app` bundle from each process executable path, grouping renderers and GPU helpers under
one user-facing bundle identifier, name, and icon.

## Process tap lifecycle

Each application group gets a `CATapDescription(stereoMixdownOfProcesses:)` with:

```swift
description.isPrivate = true
description.muteBehavior = .mutedWhenTapped
```

`.mutedWhenTapped` is essential. Without it, audio plays through both the original path and
Volumix, causing doubled audio and phase problems. With it, Volumix is solely responsible for that
application's audio until the tap is invalidated.

This creates a strict cleanup requirement: every tap must be destroyed on normal exit, failure,
`SIGINT`, and `SIGTERM`. `SIGKILL` cannot be intercepted.

## Aggregate device recreation

When the tap list changes, Volumix stops the IOProc, destroys the aggregate device, recreates it
with the new list, and starts a new IOProc.

This behavior is based on measurement. Writing `kAudioAggregateDevicePropertyTapList` on a live
device returns `noErr`, but the device subsequently provides zero input buffers to the IOProc and
silently cuts audio. Recreation causes a millisecond-scale transition but restores a valid graph.

When the tap list is unchanged, CoreAudio objects remain in place and only gain slots are updated.

## Real-time boundary

The IOProc callback runs on a real-time audio thread. Code reachable from that callback must not:

- Allocate or free memory.
- Trigger Swift ARC retain/release traffic.
- Acquire locks or dispatch synchronously.
- Send Objective-C messages.
- Print, log, access files, or use the network.
- Use collections in ways that may allocate or trigger copy-on-write.

`mixBlock` captures only preallocated trivial pointers. `MixerSlots` owns fixed-capacity storage for
target gain, current ramped gain, RMS level, and diagnostic geometry. The UI writes target gains and
reads levels; the audio thread reads targets and writes current gain and levels.

Gain changes use a short ramp to prevent zipper noise. The UI samples RMS at 30 Hz and applies
separate attack and release smoothing.

## Main-thread responsibilities

The main thread owns all non-real-time CoreAudio lifecycle work:

- Process discovery callbacks.
- Tap creation and destruction.
- Aggregate device and IOProc creation and destruction.
- Output device listeners.
- Engine regrouping after process or device changes.

## Module map

```text
Sources/
  AudioCore/
    AppIdentity.swift       Resolve helper processes to user-facing applications.
    AudioProcess.swift      Discover processes and output devices.
    CoreAudioHelpers.swift  Typed CoreAudio property access and errors.
    ProcessMonitor.swift    Poll playback state at 1 Hz.
    ProcessTap.swift        Own one application's process tap.
    MixerEngine.swift       Own one output-specific aggregate device and IOProc.
    MixerSlots.swift        Preallocated UI/audio-thread exchange.
    MixBlock.swift          Real-time-safe mixing, gain ramping, and RMS.
    MixBlockSelfTest.swift  Synthetic regression checks.
  Volumix/
    VolumixApp.swift        Application, status item, popover, and lifecycle.
    MixerController.swift   Coordinates processes, taps, engines, devices, and settings.
    MixerView.swift         Popover composition and states.
    AppRowView.swift        Per-application controls and routing.
    PulseTrack.swift        Combined gain control and level visualization.
    Settings.swift          UserDefaults persistence.
    HotKey.swift            Global keyboard shortcut.
    LoginItem.swift         Launch-at-login integration.
    VisualEffect.swift      Native vibrancy surface.
  spike/main.swift          Manual CoreAudio measurement and regression tool.
```

## Permissions and signing

- `NSAudioCaptureUsageDescription` explains System Audio Recording access.
- `LSUIElement = true` keeps the application out of the Dock.
- TCC permission is associated with the code-signing identity. Repeated ad-hoc builds may cause
  permission resets; use a stable certificate during development and Developer ID for distribution.

## Measured baseline

Measurements used a 440 Hz reference tone with 0.366 peak amplitude on an Apple Silicon Mac:

| Question | Result |
|---|---|
| Does system volume cause double attenuation? | No. Tap RMS stayed near the theoretical 0.2588 at both 100% and 20% system volume, showing that the tap precedes device volume. |
| Setup cost | First run took about 2.5 seconds during permission flow; subsequent setup took 15–16 ms. |
| Buffer geometry | One interleaved stereo input buffer per tap at 48 kHz and 8 bytes/frame; one two-channel output buffer with 512 frames/block. |
| Estimated latency | 512 frames at 48 kHz is 10.7 ms/block; tap plus aggregate behavior was approximately two blocks, or about 21 ms. |

## Open technical questions

1. Verify behavior across a wider range of sample-rate combinations and external audio devices.
2. Confirm `coreaudiod` cleanup behavior after an unavoidable `SIGKILL` across supported macOS versions.
3. Add automated checks that can run without System Audio Recording permission or physical audio hardware.
