# Gemini instructions for Volumix

Read and follow [AGENTS.md](AGENTS.md) as the canonical repository policy before making changes.

Volumix is a Swift 6 macOS 14.4+ menu bar application built with SwiftPM and Make. Do not generate
an Xcode project or add third-party dependencies without explicit maintainer approval.

The highest-risk code is the CoreAudio IOProc path:

- No allocation, deallocation, locking, logging, file/network I/O, Objective-C messaging, or ARC
  traffic is permitted from `mixBlock` or anything it calls.
- Keep callback state preallocated and pointer-based. Mark callback-reachable functions `// RT-SAFE`.
- Perform tap, aggregate-device, IOProc, and listener lifecycle operations on the main thread.
- Preserve cleanup for every `.mutedWhenTapped` tap on normal exit, error, `SIGINT`, and `SIGTERM`.
- Recreate aggregate devices when tap membership changes; do not mutate a live tap list.

Keep UI behavior consistent with `DESIGN.md`, architecture consistent with `ARCHITECTURE.md`, and
all source text in English. Validate builds and run `swift run spike --test` after audio-path changes.
