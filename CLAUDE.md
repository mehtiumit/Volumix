# Claude instructions for Volumix

Volumix is a macOS menu bar application for per-application audio control. It uses Swift, SwiftUI,
AppKit, and CoreAudio Process Taps. Treat [AGENTS.md](AGENTS.md) as the canonical repository policy.

## Required workflow

1. Read `AGENTS.md` and `ARCHITECTURE.md` before changing the audio path.
2. Preserve the macOS 14.4 minimum deployment target.
3. Build with `make app`; use `make debug` for audio graph diagnostics.
4. Run `swift run spike --test` after changing buffer, channel, frame, gain, or RMS logic.
5. Manually verify cleanup after any tap or engine lifecycle change.

## Non-negotiable rules

- Never allocate, lock, log, perform I/O, send Objective-C messages, or capture reference types in
  the IOProc path. Mark functions callable from the callback with `// RT-SAFE`.
- Create and destroy taps, aggregate devices, and listeners on the main thread.
- Every `.mutedWhenTapped` tap must be invalidated on normal exit, failure, `SIGINT`, and `SIGTERM`.
- Do not add dependencies without maintainer approval.
- Do not create an Xcode project; this repository intentionally uses SwiftPM and a Makefile.
- Keep all source text, comments, diagnostics, UI copy, and documentation in English.
- Preserve unrelated user changes and keep patches narrowly scoped.

## Style

Prefer direct Swift over speculative abstractions. Avoid empty initializers, one-implementation
protocols, and layers added only for hypothetical future use. Comments should explain constraints
and rationale rather than restate the code. Use `// ponytail:` for a deliberate simplification and
state the condition that would justify revisiting it.
