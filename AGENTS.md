# Repository instructions

These rules apply to every human or automated contributor working in this repository.

## Project requirements

Volumix is a native macOS 14.4+ menu bar application for per-application audio control. It must:

- Discover applications that are currently producing audio.
- Apply independent gain and mute state per application.
- Route an application to a selected output device or follow the system default.
- Restore settings by bundle identifier.
- Display live levels without blocking the audio thread.
- Release every process tap and aggregate device during all catchable termination paths.
- Process audio in memory only. Never record, persist, inspect, or transmit audio samples.
- Remain a menu bar accessory with no Dock icon.

## Architecture boundaries

- `AudioCore` owns CoreAudio discovery, taps, devices, real-time mixing, and synthetic checks.
- `Volumix` owns UI, orchestration, persistence, shortcuts, and application lifecycle.
- The `spike` executable is a manual measurement and regression tool, not production UI.
- Keep the minimum deployment target at macOS 14.4 unless the maintainers explicitly change it.
- Use SwiftPM and the Makefile. Do not add an Xcode project.
- Use only Apple frameworks already in the project unless a maintainer approves a dependency.

## Real-time audio safety

The IOProc path is a hard real-time boundary. Code reachable from `mixBlock` must not:

- Allocate or deallocate memory.
- Capture Swift class instances or trigger ARC traffic.
- Acquire locks, wait on queues, or dispatch synchronously.
- Send Objective-C messages.
- Print, log, access files, or use the network.
- Use collection operations that may allocate or trigger copy-on-write.

Use preallocated trivial storage. Mark any additional callback-reachable function with
`// RT-SAFE` and explain why it satisfies the constraints.

## CoreAudio lifecycle safety

- Create and destroy process taps, aggregate devices, IOProcs, and property listeners on the main
  thread, never inside the IOProc.
- `.mutedWhenTapped` transfers responsibility for application audio to Volumix. Every created tap
  must have an obvious owner and an idempotent cleanup path.
- Preserve cleanup for normal exit, errors, application termination, `SIGINT`, and `SIGTERM`.
- Do not remove the self-process filter or set-based process comparison in `ProcessMonitor`.
- Keep `systemsoundserverd` on the system passthrough list so transient alerts cannot rebuild the
  aggregate device around applications that are already playing.
- Recreate the aggregate device when its tap list changes. Live tap-list mutation has been measured
  to produce zero input buffers even when CoreAudio returns success.
- Keep one `MixerSlots` instance per `MixerEngine`; sharing slots across outputs corrupts routing.

## UI and product behavior

- Follow `DESIGN.md` for layout, semantic colors, typography, and states.
- Keep user-facing strings concise and in English.
- Use semantic system colors and native materials; support light and dark appearance.
- Preserve the combined gain/activity meaning of PulseTrack: pulse is clipped inside gain fill.
- Keep metering inactive while the panel is closed.
- Maintain accessible labels and adequate hit targets for icon-only controls.

## Code style

- Prefer direct, readable Swift over speculative abstractions.
- Do not add empty initializers, one-implementation protocols, or future-only layers.
- Comments explain rationale, constraints, measured behavior, and ownership—not obvious syntax.
- Use `// ponytail:` for a deliberate simplification and state the condition for revisiting it.
- Keep all code, comments, diagnostics, test output, UI copy, and documentation in English.
- Keep changes narrowly scoped and preserve unrelated work.

## Validation

Run checks proportional to the change:

```sh
swift build -c debug
swift build -c release --product Volumix
swift run spike --test
make app
codesign --verify --deep --strict Volumix.app
plutil -lint Volumix.app/Contents/Info.plist
```

For audio lifecycle changes, also perform the manual test:

1. Start audio in at least one application.
2. Change gain and mute state.
3. Confirm the audible result and stable output.
4. Quit Volumix normally and confirm audio returns to its original path.
5. Repeat with `SIGTERM` when signal handling is in scope.

Document hardware-dependent tests that could not be run.
