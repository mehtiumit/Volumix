import AppKit
import AudioCore
import CoreAudio
import Observation
import SwiftUI

@Observable
final class MixerController {
    struct Row: Identifiable {
        let identity: AppIdentity
        var gain: Float
        var muted: Bool
        /// nil = follow the default output.
        var outputUID: String?
        var level: Float = 0

        var id: String { identity.bundleID }
        /// The engine and slot that own the gain. The UI does not see this routing detail.
        fileprivate var engineUID: String = ""
        fileprivate var slot: Int = 0
    }

    private(set) var rows: [Row] = []
    private(set) var outputs: [(id: AudioObjectID, name: String, uid: String)] = []
    private(set) var defaultOutputName = ""
    private(set) var masterVolume: Float = 1
    private(set) var failure: String?

    private var settings = Settings()
    private var monitor: ProcessMonitor?
    private var engines: [String: MixerEngine] = [:]
    private var taps: [String: ProcessTap] = [:]      // bundleID -> tap
    private var levelTimer: Timer?
    private var deviceListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    init() {
        // Taps use .mutedWhenTapped. If they are not removed during termination, application audio
        // can remain muted. See rule 2 in CLAUDE.md.
        for signalNumber in [SIGINT, SIGTERM] { signal(signalNumber, SIG_IGN) }
        for signalNumber in [SIGINT, SIGTERM] {
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                self?.shutdown()
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.shutdown() }

        refreshOutputs()
        observeDefaultOutput()
        monitor = ProcessMonitor { [weak self] processes in
            self?.rebuild(with: processes)
        }

        guard Self.debug else { return }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            for row in rows {
                guard let engine = engines[row.engineUID] else { continue }
                let geometry = engine.slots.geometry
                log("\(row.identity.name) level=\(engine.slots.level(slot: row.slot)) "
                    + "targetGain=\(engine.slots.gain(slot: row.slot)) "
                    + "inputBuffers=\(geometry.inBuffers) outputBuffers=\(geometry.outBuffers) "
                    + "frame=\(geometry.frames)")
            }
        }
    }

    private var signalSources: [DispatchSourceSignal] = []

    // MARK: - UI actions

    func setGain(_ gain: Float, for bundleID: String) {
        guard let index = rows.firstIndex(where: { $0.id == bundleID }) else { return }
        rows[index].gain = gain
        settings[bundleID].gain = gain
        applyGain(rows[index])
    }

    func toggleMute(_ bundleID: String) {
        guard let index = rows.firstIndex(where: { $0.id == bundleID }) else { return }
        rows[index].muted.toggle()
        settings[bundleID].muted = rows[index].muted
        applyGain(rows[index])
    }

    func setOutput(_ uid: String?, for bundleID: String) {
        settings[bundleID].outputUID = uid
        rebuild(with: monitor?.playing ?? [])
    }

    private func applyGain(_ row: Row) {
        let engine = engines[row.engineUID]
        engine?.slots.setGain(row.muted ? 0 : row.gain, slot: row.slot)
        log("gain \(row.identity.name) → \(row.muted ? 0 : row.gain) "
            + "engine=\(row.engineUID.isEmpty ? "NONE" : row.engineUID) slot=\(row.slot) "
            + "engineFound=\(engine != nil)")
    }

    // MARK: - Audio graph

    /// Inspect audio graph setup with `VOLUMIX_DEBUG=1 Volumix.app/Contents/MacOS/Volumix`.
    private static let debug = ProcessInfo.processInfo.environment["VOLUMIX_DEBUG"] != nil
    private func log(_ message: @autoclosure () -> String) {
        guard Self.debug else { return }
        FileHandle.standardError.write(Data("[volumix] \(message())\n".utf8))
    }

    private func rebuild(with processes: [AudioProcess]) {
        failure = nil
        guard let defaultUID = try? AudioDevices.defaultOutputUID else {
            failure = "Unable to read the default output device"
            return
        }

        // Group all helper processes for one application into a single row and tap.
        var byApp: [String: (identity: AppIdentity, processes: [AudioObjectID])] = [:]
        for process in processes {
            let identity = AppIdentity.resolve(pid: process.pid, fallbackBundleID: process.bundleID)
            byApp[identity.bundleID, default: (identity, [])].processes.append(process.id)
        }
        // Tapping our own audio creates feedback. `ProcessMonitor` already filters by PID, but this
        // deliberate second guard protects users if that filter is ever loosened.
        byApp[Bundle.main.bundleIdentifier ?? "com.volumix.app"] = nil

        for bundleID in taps.keys where byApp[bundleID] == nil {
            taps.removeValue(forKey: bundleID)?.invalidate()
        }

        var grouped: [String: [(bundleID: String, identity: AppIdentity, tap: ProcessTap)]] = [:]
        var newRows: [Row] = []

        for (bundleID, entry) in byApp.sorted(by: { $0.value.identity.name < $1.value.identity.name }) {
            let tap: ProcessTap
            if let existing = taps[bundleID], existing.processIDs == entry.processes {
                tap = existing
            } else {
                taps.removeValue(forKey: bundleID)?.invalidate()
                do {
                    tap = try ProcessTap(processes: entry.processes, label: entry.identity.name)
                } catch {
                    failure = error.localizedDescription
                    log("TAP ERROR \(entry.identity.name): \(error.localizedDescription)")
                    continue
                }
                taps[bundleID] = tap
                log("tap created \(entry.identity.name) processes=\(entry.processes) tapID=\(tap.tapID)")
            }
            let setting = settings[bundleID]
            // Fall back to the default if the selected device was removed. Preserve the setting so
            // the user's choice returns when the device is reconnected.
            let available = Set(outputs.map(\.uid))
            let targetUID = setting.outputUID.flatMap { available.contains($0) ? $0 : nil } ?? defaultUID
            grouped[targetUID, default: []].append((bundleID, entry.identity, tap))
            newRows.append(Row(identity: entry.identity,
                               gain: setting.gain,
                               muted: setting.muted,
                               outputUID: setting.outputUID))
        }

        for uid in engines.keys where grouped[uid] == nil {
            engines.removeValue(forKey: uid)?.invalidate()
        }

        for (uid, members) in grouped {
            let engine = engines[uid] ?? {
                let new = MixerEngine(outputUID: uid)
                engines[uid] = new
                return new
            }()
            let gains = members.map { member -> Float in
                let setting = settings[member.bundleID]
                return setting.muted ? 0 : setting.gain
            }
            do {
                try engine.setTaps(members.map(\.tap), gains: gains)
                log("engine \(uid): \(members.map(\.identity.name)) gains=\(gains)")
            } catch {
                failure = error.localizedDescription
                log("ENGINE ERROR \(uid): \(error.localizedDescription)")
                continue
            }
            for (slot, member) in members.enumerated() {
                guard let index = newRows.firstIndex(where: { $0.id == member.bundleID }) else { continue }
                newRows[index].engineUID = uid
                newRows[index].slot = slot
            }
        }

        rows = newRows
    }

    // MARK: - Devices

    private func refreshOutputs() {
        outputs = (try? AudioDevices.outputs()) ?? []
        guard let device = try? AudioDevices.defaultOutputID else { return }
        defaultOutputName = (try? AudioDevices.name(of: device)) ?? ""
        masterVolume = AudioDevices.volume(of: device) ?? 1
    }

    /// System output volume. This belongs to the device and is independent of the mixer.
    func setMasterVolume(_ volume: Float) {
        guard let device = try? AudioDevices.defaultOutputID else { return }
        AudioDevices.setVolume(volume, of: device)
        masterVolume = volume
    }

    /// Rebuild the graph when the default output changes or devices are connected or removed.
    private func observeDefaultOutput() {
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDevices] {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                guard let self else { return }
                refreshOutputs()
                rebuild(with: monitor?.playing ?? [])
            }
            var address = AudioObjectPropertyAddress.address(selector)
            guard AudioObjectAddPropertyListenerBlock(.system, &address, .main, block) == noErr else { continue }
            deviceListeners.append((address, block))
        }
    }

    // MARK: - Level meter

    /// Runs only while the panel is open; waking the CPU at 30 Hz while hidden has no value.
    func startMetering() {
        guard levelTimer == nil else { return }
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            // Keyboard volume keys do not trigger the CoreAudio listener. Reuse the timer that is
            // already active while the panel is open instead of adding another observer.
            if let device = try? AudioDevices.defaultOutputID,
               let volume = AudioDevices.volume(of: device), abs(volume - masterVolume) > 0.001 {
                masterVolume = volume
            }
            // Raw RMS jitters. A one-pole filter supplies the design's meter ballistics:
            // 45 ms attack and 180 ms release. k = 1 - exp(-dt/τ), dt = 1/30 s.
            let attack: Float = 0.52
            let release: Float = 0.17
            for index in rows.indices {
                let raw = engines[rows[index].engineUID]?.slots.level(slot: rows[index].slot) ?? 0
                let level = rows[index].level
                rows[index].level = level + (raw - level) * (raw > level ? attack : release)
            }
        }
    }

    func stopMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    func shutdown() {
        stopMetering()
        for (address, block) in deviceListeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(.system, &address, .main, block)
        }
        deviceListeners.removeAll()
        monitor?.invalidate()
        for engine in engines.values { engine.invalidate() }
        engines.removeAll()
        for tap in taps.values { tap.invalidate() }
        taps.removeAll()
    }
}
