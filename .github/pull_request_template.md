## Summary

Describe the problem and the change.

## Validation

- [ ] `swift build -c debug`
- [ ] `swift build -c release --product Volumix`
- [ ] `swift run spike --test` when audio math changed
- [ ] `make app`
- [ ] Manual audio and cleanup test when CoreAudio lifecycle changed

List macOS version, hardware, output devices, and any checks that could not be run.

## UI changes

Attach screenshots or a short recording when applicable.

## Safety checklist

- [ ] No allocation, locking, logging, I/O, Objective-C messaging, or ARC traffic was added to the IOProc path.
- [ ] Every new `.mutedWhenTapped` tap has an idempotent cleanup path.
- [ ] User-facing text and documentation are in English.
