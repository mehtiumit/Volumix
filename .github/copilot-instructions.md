# GitHub Copilot instructions

Volumix is a native Swift 6 menu bar audio mixer for macOS 14.4+. Use SwiftPM and the Makefile; do
not introduce an Xcode project or third-party package unless explicitly requested.

Follow these rules when generating or editing code:

- Treat `AGENTS.md` as the canonical contributor policy and `ARCHITECTURE.md` as the audio design.
- Never allocate, lock, log, perform I/O, send Objective-C messages, or capture reference types in
  the IOProc callback path. Keep it real-time safe and use preallocated storage.
- Create and destroy taps, aggregate devices, IOProcs, and listeners on the main thread.
- Every `.mutedWhenTapped` tap requires idempotent cleanup on all catchable termination paths.
- Preserve one `MixerSlots` table per output-specific `MixerEngine`.
- Preserve the 1 Hz process polling, self-PID filter, and set-based process comparison.
- Recreate aggregate devices when tap lists change; live mutation is known to yield zero buffers.
- Follow `DESIGN.md`, use semantic system colors, and keep metering off while the panel is closed.
- Keep code, comments, diagnostics, UI strings, and documentation in English.
- Prefer small direct changes and comments that explain rationale rather than syntax.

For audio-path edits, suggest or run `swift run spike --test` and a release build.
