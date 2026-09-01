import SwiftUI

/// The panel's only custom control. See DESIGN.md → "PulseTrack".
///
/// This replaces the system `Slider` for function, not styling: the level meter sits *inside* the
/// fill. One line therefore communicates both attenuation and current audio activity, avoiding a
/// second column in a 288 pt panel.
///
/// Four layers, each 3 pt high with a 1 pt corner radius: track · fill · pulse · core.
struct PulseTrack: View {
    var value: Float
    var level: Float
    var dimmed: Bool
    var onChange: (Float) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fill = width * CGFloat(min(max(value, 0), 1))
            // Keep the pulse inside the fill, making its track length `level × volume`. Attenuation
            // shortens the pulse too, so the control represents what the user hears instead of raw RMS.
            // ponytail: The 3.5 calibration factor was tuned by ear. Music RMS typically sits near
            // 0.2, so amplification makes use of the visible range. Move this to settings only if
            // device-specific differences become a reported problem.
            let pulse = fill * CGFloat(min(1, level * 3.5))

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(nsColor: .quaternaryLabelColor))

                Rectangle()
                    .fill(.tint.opacity(dimmed ? 0.25 : 0.5))
                    .frame(width: fill)

                // A muted application has no pulse: the bar should not move when no audio is audible.
                if !dimmed {
                    Rectangle()
                        .fill(.tint)
                        .frame(width: pulse)
                        .overlay(alignment: .top) { core }
                        // The meter updates at 30 Hz; linear interpolation removes tick-to-tick jitter.
                        .animation(.linear(duration: 1.0 / 30), value: level)
                }
            }
            .frame(height: 3)
            .clipShape(.rect(cornerRadius: 1))
            // Keep the thumb *outside* clipping so its 11 pt height can extend beyond the 3 pt track.
            .overlay(alignment: .leading) {
                if hovering || dragging {
                    Rectangle()
                        .fill(Color(nsColor: .labelColor))
                        .frame(width: 2, height: 11)
                        .clipShape(.rect(cornerRadius: 1))
                        .offset(x: min(max(fill - 1, 0), width - 2))
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        dragging = true
                        onChange(Float(min(max(drag.location.x / width, 0), 1)))
                    }
                    .onEnded { _ in dragging = false }
            )
        }
        .frame(height: 16)   // 3 pt visual, 16 pt hit target.
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }

    /// A lighter stripe inside the pulse. The design specifies "accent + 55% white"; white at 55%
    /// alpha over opaque accent gives the same result. (`Color.mix` requires macOS 15; minimum is 14.4.)
    private var core: some View {
        Rectangle()
            .fill(.white.opacity(scheme == .dark ? 0.45 : 0.55))
            .frame(height: 1)
            .offset(y: 1)
    }
}
