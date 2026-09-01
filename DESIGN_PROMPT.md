# Volumix visual design brief

Use this brief when exploring future visual directions. `DESIGN.md` remains authoritative for the
implemented interface.

Design a compact, premium macOS menu bar audio mixer named Volumix. The application controls the
volume of currently playing applications, shows live activity, supports mute, and optionally routes
each application to another output device.

## Product character

- Native, precise, quiet, and professional.
- More like a first-party macOS utility than a music-production console.
- Dense enough for fast use, but never cramped or decorative.
- Glass and vibrancy should come from native macOS materials, not simulated gradients.
- Use the user's system accent color and semantic labels throughout.

## Required composition

The panel is 288 pt wide and contains:

1. A master output row with device name, percentage, and slim volume control.
2. Zero or more 56 pt application rows with icon, name, percentage, mute, PulseTrack, and optional
   output-routing affordance.
3. A restrained footer with settings and quit controls.

The application list may scroll but the master and footer remain fixed.

## Signature control

PulseTrack is a slim custom control combining volume and audio activity in one horizontal line.
The track shows available range, fill shows configured gain, and a brighter pulse inside the fill
shows audible activity. The pulse must be clipped to the fill. A narrow thumb appears on hover or
drag and disappears at rest.

## Interaction states to explore

- Several applications playing at different levels.
- Hovered application with visible thumb and routing affordance.
- Muted application with crossed-out accent icon and no pulse.
- Application routed to a named external output.
- Empty state with the master output still usable.
- Missing audio permission with a direct System Settings action.
- Light and dark appearance with blue, purple, orange, pink, green, and graphite accents.

## Avoid

- Large rounded cards inside the popover.
- Fixed brand gradients or hard-coded colors.
- Oversized typography, album art, waveforms, or decorative charts.
- Separate level-meter columns that widen the panel.
- Web-style toggles, pill buttons, or excessive borders.
- Motion that continues when no audio is audible.
