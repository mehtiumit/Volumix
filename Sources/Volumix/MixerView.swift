import AppKit
import AudioCore
import SwiftUI

/// See DESIGN.md → "Vertical structure". Master 62 · divider · 56·n (max 320) · divider · footer 38.
struct MixerView: View {
    @Bindable var controller: MixerController

    var body: some View {
        VStack(spacing: 0) {
            // With no rows, an error owns the body (design G) because permission failure leaves
            // nothing useful below it. With rows, the error is partial and appears below working rows.
            if let failure = controller.failure, controller.rows.isEmpty {
                failureLine(failure)
            } else {
                master
                Hairline()

                if controller.rows.isEmpty {
                    empty
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(controller.rows) { row in
                                AppRowView(row: row, controller: controller)
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                    .scrollIndicators(.never)
                }

                if let failure = controller.failure {
                    Hairline()
                    failureLine(failure)
                }
            }

            Hairline()
            footer
        }
        .frame(width: 288)
        .background(VisualEffect())
    }

    // MARK: - Master output

    private var master: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Text(controller.defaultOutputName)
                    .font(.system(size: 12, weight: .medium))
                    .kerning(-0.07)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(Int(controller.masterVolume * 100))%")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(height: 17)

            // System output volume is independent of this mixer, so it has no pulse.
            PulseTrack(
                value: controller.masterVolume,
                level: 0,
                dimmed: false,
                onChange: controller.setMasterVolume
            )
            .frame(height: 16)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - States

    private var empty: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("No applications are playing audio")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        // Preserve list height while empty so the panel does not jump when playback starts.
        .frame(maxWidth: .infinity)
        .frame(height: 96)
    }

    /// Missing audio capture permission is the most likely cause, but `OSStatus` does not identify
    /// it reliably. Present the same recovery path for every failure.
    private func failureLine(_ message: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .lineLimit(2)
            Spacer(minLength: 6)
            Button("Open Audio Permissions") {
                NSWorkspace.shared.open(URL(
                    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture"
                )!)
            }
            .buttonStyle(.link)
            .font(.system(size: 11))
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }

    // ponytail: Footer icons do not change color on hover, though the design promotes them to
    // labelColor. That would require two @State values and the 28 pt hit targets already provide
    // feedback. Revisit only if users report the issue.
    private var footer: some View {
        HStack(spacing: 0) {
            Menu {
                Toggle("Launch at Login", isOn: Binding(
                    get: { LoginItem.enabled },
                    set: { LoginItem.enabled = $0 }
                ))
                Divider()
                Text("Open Panel  ⌥⌘V")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                controller.shutdown()
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .frame(height: 38)
    }
}
