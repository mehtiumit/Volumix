import AudioCore
import CoreAudio
import Foundation

// Phase 0 validation. Measures the open questions documented in ARCHITECTURE.md:
//   1. Does tap gain actually attenuate audio?
//   2. Does buffer geometry match the slot-mapping assumption?
//   3. How much latency does the chain add?
//   4. Are taps cleaned up on exit?
//
//   swift run spike                       → list audio-producing applications
//   swift run spike Spotify 0.3 20        → play at 30% gain for 20 seconds

func listProcesses() throws {
    let processes = try AudioProcess.all().filter { !$0.bundleID.isEmpty }
    print("PID     PLAYING  BUNDLE")
    for process in processes.sorted(by: { $0.isRunningOutput && !$1.isRunningOutput }) {
        let pid = String(process.pid).padding(toLength: 8, withPad: " ", startingAt: 0)
        print("\(pid)\(process.isRunningOutput ? "▶      " : "-      ")\(process.bundleID)")
    }
    let output = try AudioDevices.defaultOutputID
    print("\nDefault output: \(try AudioDevices.name(of: output))  [\(try AudioDevices.uid(of: output))]")
}

func run(match: String, gain: Float, seconds: Double) throws {
    let candidates = try AudioProcess.playing().filter {
        $0.bundleID.localizedCaseInsensitiveContains(match)
    }
    guard let process = candidates.first else {
        print("No audio-producing application matches '\(match)'. Start playback first.")
        return
    }
    print("Target: \(process.bundleID) (pid \(process.pid))")

    let tap = try ProcessTap(processes: [process.id], label: process.bundleID)
    let outputUID = try AudioDevices.defaultOutputUID
    let engine = MixerEngine(outputUID: outputUID)
    let slots = engine.slots

    // Close the tap on every path: normal exit, Ctrl-C, and failure. Otherwise audio may remain muted.
    let cleanup = {
        engine.invalidate()
        tap.invalidate()
    }
    var signalSource: DispatchSourceSignal?
    signal(SIGINT, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    source.setEventHandler { cleanup(); print("\nCleaned up."); exit(0) }
    source.resume()
    signalSource = source
    defer { cleanup(); _ = signalSource }

    if let format = tap.format {
        print(String(format: "Tap format: %.0f Hz, %d channels, %d bytes/frame",
                     format.mSampleRate, format.mChannelsPerFrame, format.mBytesPerFrame))
    }

    let started = Date()
    try engine.setTaps([tap], gains: [gain])
    print(String(format: "Setup time: %.0f ms", Date().timeIntervalSince(started) * 1000))
    print("Applying \(Int(gain * 100))% gain for \(Int(seconds)) seconds...\n")

    var reported = false
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        let geometry = slots.geometry
        if !reported, geometry.inBuffers > 0 {
            reported = true
            print("""
            Block geometry:
              input buffers : \(geometry.inBuffers)  (tap count: \(engine.tapCount))
              output buffers: \(geometry.outBuffers)
              input channels: \(geometry.inChannels)
              output channels: \(geometry.outChannels)
              frames/block  : \(geometry.frames)
            """)
            if geometry.inBuffers != engine.tapCount {
                print("  ⚠︎ input buffer count differs from tap count; slot mapping must be revised")
            }
        }
        let level = slots.level(slot: 0)
        let bars = Int(min(1, level * 4) * 30)
        print("\r  level [\(String(repeating: "█", count: bars))\(String(repeating: " ", count: 30 - bars))] "
              + String(format: "%.4f", level), terminator: "")
        fflush(stdout)
    }
    print("\n\nDone.")
}

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    if arguments.first == "--test" {
        mixBlockSelfTest()
    } else if arguments.isEmpty {
        try listProcesses()
    } else {
        try run(match: arguments[0],
                gain: arguments.count > 1 ? Float(arguments[1]) ?? 0.3 : 0.3,
                seconds: arguments.count > 2 ? Double(arguments[2]) ?? 15 : 15)
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
