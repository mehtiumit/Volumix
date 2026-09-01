# Building and development

## Prerequisites

- macOS 14.4 or later.
- Swift 6.1 or later.
- Xcode Command Line Tools (`xcode-select --install`).
- System Audio Recording permission for end-to-end audio tests.

The repository intentionally does not contain an Xcode project. SwiftPM and Make are the supported
build interfaces.

## Build commands

```sh
make app      # Release build, application bundle, and local ad-hoc signature.
make run      # Build and launch the application bundle.
make debug    # Build and run in the terminal with VOLUMIX_DEBUG=1.
make stop     # Stop all running Volumix instances and wait for cleanup.
make clean    # Remove .build and Volumix.app.
```

`make app` stops a running instance before replacing the bundle. This avoids LaunchServices error
`-609` and prevents two mixer instances from racing for the same process taps.

## Local signing

The default build uses an ad-hoc signature:

```sh
make app SIGN_ID=-
```

TCC associates System Audio Recording permission with signing identity. Ad-hoc signatures may
cause permission prompts to reset after rebuilds. A stable local or Developer ID certificate can be
provided explicitly:

```sh
make app SIGN_ID="Developer ID Application: Your Name (TEAMID)"
```

## Verification

```sh
swift build -c debug
swift build -c release --product Volumix
swift run spike --test
make app
codesign --verify --deep --strict Volumix.app
plutil -lint Volumix.app/Contents/Info.plist
```

The synthetic spike test checks gain, mute, frame boundaries, non-interleaved output, multichannel
bounds, and pre-gain RMS without requiring live audio hardware.

## Manual audio test

1. Start playback in Spotify, a browser, or another application.
2. Run `make debug`.
3. Open Volumix from the menu bar.
4. Change gain and mute state and verify the audible result.
5. Route the application to another output if one is available.
6. Quit Volumix and verify the application returns to its original system audio route.

CoreAudio behavior can vary by device. Include hardware and sample-rate details in bug reports.
