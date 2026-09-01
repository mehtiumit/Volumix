import AppKit
import SwiftUI

/// Glass background. SwiftUI's `.ultraThinMaterial` is an *in-window* layer, while a popover needs
/// `behindWindow` blending to blur the desktop behind it. Only `NSVisualEffectView` provides that.
/// The material follows the system appearance and accent color, avoiding a hand-built palette.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// A hairline separating sections. It is inset by 14 pt rather than full width so the panel's
/// horizontal alignment remains consistent.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 0.5)
            .padding(.horizontal, 14)
    }
}
