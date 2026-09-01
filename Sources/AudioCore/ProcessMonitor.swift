import CoreAudio
import Foundation

/// Tracks audio-producing processes continuously.
///
/// **Polling is required, not preferred.** CoreAudio accepts
/// `AudioObjectAddPropertyListenerBlock` for `kAudioProcessPropertyIsRunningOutput` and returns
/// `noErr`, but sends no notification when the value changes. Measurement confirmed that Spotify
/// pause/play changed the property 1→0→1 and polling observed it, while no notification arrived.
/// `kAudioHardwarePropertyProcessObjectList` was silent as well. Both nonfunctional listeners were
/// removed; their observable symptom was Spotify never appearing when started while Brave played.
public final class ProcessMonitor {
    public private(set) var playing: [AudioProcess] = []

    private let onChange: ([AudioProcess]) -> Void
    private var timer: Timer?

    /// `onChange` always runs on the main thread, where CoreAudio setup must occur.
    public init(onChange: @escaping ([AudioProcess]) -> Void) {
        self.onChange = onChange
        refresh()
        // 1 Hz is fast enough to restore an application's saved level when playback begins.
        // Roughly 35 processes × three property reads is negligible for a menu bar application.
        // Polling must continue while the panel is closed so a saved 30% gain still applies.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        // Excluding this process is required, not cosmetic. The aggregate device IOProc makes us
        // an output-writing process too. Recreating the engine toggles that flag, so without this
        // filter every poll would rebuild the audio graph. Tapping our own audio also creates feedback.
        let nowPlaying = ((try? AudioProcess.playing()) ?? []).filter { $0.pid != getpid() }

        // Compare sets, not order: CoreAudio does not guarantee array order. Ordered comparison
        // would rebuild the graph after harmless shuffles and produce an audible gap.
        guard Set(nowPlaying.map(\.id)) != Set(playing.map(\.id)) else { return }
        playing = nowPlaying
        onChange(nowPlaying)
    }

    public func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    deinit { invalidate() }
}
