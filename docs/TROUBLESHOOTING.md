# Troubleshooting

## The build says “replacing existing signature”

That message is informational, not a failure. The Makefile suppresses successful signing chatter
and still prints the full output when signing fails.

## Volumix launches but no window appears

Volumix is a menu bar application and intentionally has no Dock icon or standard launch window.
Select the slider icon in the macOS menu bar or press `⌥⌘V`.

## No applications appear

- Confirm an application is actively producing audio, not merely open or paused.
- Grant Volumix System Audio Recording permission in System Settings → Privacy & Security.
- Quit and relaunch Volumix after changing permission.
- Run `make debug` and inspect process discovery and tap creation messages.

## Permission keeps resetting

TCC permission is associated with code-signing identity. Ad-hoc development builds may receive a
different identity after rebuilding. Use a stable signing certificate as described in
[Building](BUILDING.md).

## Audio remains muted after exit

This is a high-priority lifecycle failure. First stop Volumix with `make stop`. If audio does not
recover, stop and restart the affected application or restart Core Audio by logging out and back in.
Then file a bug with the exit method, macOS version, affected application, and `make debug` output.

Do not repeatedly force-kill Volumix while a tap is active; `SIGKILL` cannot run cleanup handlers.

## An output device does not work

Disconnect and reconnect the device, then choose it again. Devices with unusual or incompatible
sample rates may not form a usable aggregate graph. Include device model and configured sample rate
in reports.

## LaunchServices error -609

This can occur if an application bundle is replaced while its executable is still running. Use
`make run`, which stops the existing instance and waits before rebuilding the bundle.
