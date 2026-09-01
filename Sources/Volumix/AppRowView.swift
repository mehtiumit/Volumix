import AppKit
import AudioCore
import SwiftUI

/// See DESIGN.md → "Application row". 56 pt: 7 top + 17 title + 8 gap + 16 control + 8 bottom.
struct AppRowView: View {
    let row: MixerController.Row
    @Bindable var controller: MixerController

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                icon
                Text(row.identity.name)
                    .font(.system(size: 12))
                    .kerning(-0.07)          // 12 pt × -0.006em
                    .lineLimit(1)
                    .foregroundStyle(row.muted ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))

                // Show the routing badge only on hover or when a non-default device is selected.
                // Keeping it visible would leave too little room for names in the 288 pt panel.
                if hovering || routedName != nil {
                    routeMenu
                }
                if let routedName {
                    Text(routedName)
                        .font(.system(size: 10))
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text("\(Int(row.gain * 100))%")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(row.muted ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
            }
            .frame(height: 17)

            HStack(spacing: 8) {
                Button(action: { controller.toggleMute(row.id) }) {
                    Image(systemName: symbol)
                        .font(.system(size: 11))
                        .frame(width: 14, height: 14)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                // When muted, this crossed-out accent-colored icon is the only state indicator.
                .foregroundStyle(muteTint)

                PulseTrack(
                    value: row.gain,
                    level: row.level,
                    dimmed: row.muted,
                    onChange: { controller.setGain($0, for: row.id) }
                )
            }
            .frame(height: 16)
        }
        .padding(.horizontal, 14)
        .padding(.top, 7)
        .padding(.bottom, 8)
        .background {
            // Inset the background by 8 pt horizontally and 2 pt vertically. An edge-to-edge
            // rectangle would break the panel's 14 pt alignment.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.accentColor.opacity(scheme == .dark ? 0.10 : 0.07))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .opacity(hovering ? 1 : 0)
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }

    private var icon: some View {
        Group {
            if let url = row.identity.bundleURL {
                // macOS application icons already have shaped corners; clipping would round them twice.
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().padding(1)
            }
        }
        .frame(width: 15, height: 15)
        .opacity(row.muted ? 0.42 : 1)
    }

    /// Target device name when routed away from the default output; otherwise nil.
    private var routedName: String? {
        row.outputUID.flatMap { uid in controller.outputs.first { $0.uid == uid }?.name }
    }

    private var muteTint: AnyShapeStyle {
        if row.muted { return AnyShapeStyle(.tint) }
        return AnyShapeStyle(hovering ? .primary : .secondary)
    }

    private var symbol: String {
        if row.muted { return "speaker.slash.fill" }
        switch row.gain {
        case ..<0.01: return "speaker.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private var routeMenu: some View {
        Menu {
            Button("Default Output") { controller.setOutput(nil, for: row.id) }
            Divider()
            ForEach(controller.outputs, id: \.uid) { device in
                Button(device.name) { controller.setOutput(device.uid, for: row.id) }
            }
        } label: {
            Image(systemName: "hifispeaker.2.fill")
                .font(.system(size: 10))
                .frame(width: 12, height: 12)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(routedName == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
    }
}
