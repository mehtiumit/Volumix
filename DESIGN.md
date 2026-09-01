# Volumix panel design specification

This document is the implementation reference for the menu bar panel. Measurements are in points
and map directly to SwiftUI. Colors use semantic system values so the panel follows appearance and
accent-color changes automatically.

## Design principles

- Look native to macOS rather than like a web dashboard.
- Keep the panel compact, calm, and readable at a glance.
- Use motion only to communicate live audio or direct interaction.
- Represent application gain and audible activity in one control.
- Preserve stable geometry as applications start and stop playing.
- Use semantic system colors; do not introduce a fixed light/dark palette.

## Color contract

| Role | macOS semantic color |
|---|---|
| Primary labels and active thumb | `labelColor` |
| Secondary text and icons | `secondaryLabelColor` |
| Muted labels | `tertiaryLabelColor` |
| Track | `quaternaryLabelColor` |
| Separators | `separatorColor` |
| Fill | `Color.accentColor.opacity(0.5)` |
| Muted fill | `Color.accentColor.opacity(0.25)` |
| Live pulse | `Color.accentColor` |
| Hover background | Accent at 7% light / 10% dark opacity |

Do not replace semantic colors with copied hex values. Volumix must remain legible in light mode,
dark mode, graphite appearance, and every system accent color.

## Surface and panel geometry

- Panel width: 288 pt.
- Panel corner radius: provided by `NSPopover`.
- Horizontal content inset: 14 pt.
- Separators: 0.5 pt, inset by 14 pt.
- Background: `NSVisualEffectView` with `.popover`, `.behindWindow`, and `.active` state.
- Scrollable application list maximum height: 320 pt.

`NSVisualEffectView` is intentional. SwiftUI material is an in-window layer and does not provide
the same behind-window desktop blur for this popover.

## Vertical structure

```text
Master output                 62
Separator                      0.5
Application row × n           56 × n, list capped at 320
Separator                      0.5
Footer                         38
```

The empty application state reserves 96 pt so the panel does not jump when playback begins.

## Master output

- Padding: 12 pt top, 14 pt horizontal, 8 pt bottom.
- Internal vertical spacing: 9 pt.
- Title row: 17 pt high, device name at 12 pt medium, percentage at 11 pt.
- Percentage uses tabular digits.
- PulseTrack row: 16 pt hit target with a 3 pt visual track.
- The master control has no live pulse because it represents physical device volume, not a tapped
  application signal.

## Application row

- Height: 56 pt.
- Padding: 7 pt top, 14 pt horizontal, 8 pt bottom.
- Application icon: 15 × 15 pt.
- Name: 12 pt, one line, tail truncation.
- Percentage: 11 pt, secondary, tabular digits.
- Mute icon hit region: 14 × 14 pt.
- PulseTrack: remaining width, 16 pt hit target.
- Hover background: inset 8 pt horizontally and 2 pt vertically, 3 pt corner radius.

Show the output-routing badge on row hover or whenever a non-default output is selected. A routed
device name uses 10 pt accent text and may truncate.

### Muted state

- Reduce application icon opacity to 42%.
- Render name and percentage with tertiary styling.
- Use the crossed-out speaker icon in the accent color.
- Reduce fill opacity to 25%.
- Hide pulse and core because muted audio is not audible.

## PulseTrack

PulseTrack combines a volume control and a VU-style activity meter. It has four 3 pt layers with a
1 pt corner radius:

1. Track: full width, quaternary label color.
2. Fill: `width × gain`, accent at 50% opacity.
3. Pulse: clipped inside the fill, `fill × calibratedLevel`, opaque accent.
4. Core: a 1 pt lighter stripe inside the pulse.

Because the pulse is clipped inside the fill, its visible length represents current audible output
rather than raw input RMS. Reducing gain shortens both fill and pulse.

The thumb is 2 × 11 pt, uses label color, and appears only during hover or drag. The 16 pt hit target
surrounds the 3 pt visual track.

The UI samples levels at 30 Hz and applies a fast attack and slower release. Interpolate between
updates to avoid visible stepping.

## States

### No applications playing

Show a centered secondary `speaker.slash` icon and the text "No applications are playing audio"
inside a 96 pt list area. Keep the master control active.

### Audio access or graph failure

If there are no working rows, replace the body with a 52 pt error line. If some rows still work,
show the error below them. Include an orange warning icon, a concise message, and an "Open Audio
Permissions" link to System Settings.

### Footer

- Height: 38 pt with 6 pt horizontal padding.
- Gear and power actions use 28 × 28 pt hit targets and 12 pt symbols.
- The gear menu contains Launch at Login and the `⌥⌘V` shortcut reminder.

## Typography

Use San Francisco through SwiftUI system fonts:

| Size | Use |
|---|---|
| 12 pt | Application and device names; medium weight for master device |
| 11 pt | Percentages, empty/error copy, footer copy |
| 10 pt | Routed output device name |

All percentages use `.monospacedDigit()` so dragging does not shift adjacent content.

## Accessibility

- Preserve system colors and contrast behavior.
- Provide accessibility descriptions for icon-only controls.
- Keep interactive hit targets larger than their visual glyphs.
- Do not rely on color alone for mute or routing state.
- Respect reduced-motion preferences when adding new animations.
