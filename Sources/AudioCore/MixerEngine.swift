import CoreAudio
import Foundation

/// A private aggregate device and IOProc carrying every tap routed to one output device.
///
/// The default scenario has one engine. Routing an application to another device creates a second
/// engine, so per-application output routing does not require a separate architecture.
public final class MixerEngine {
    public let outputUID: String
    /// The slot table belongs to the engine. If two engines shared one table, both would start at
    /// slot zero and their gains would interfere with each other.
    public let slots = MixerSlots()
    private var deviceID: AudioObjectID = .unknown
    private var ioProcID: AudioDeviceIOProcID?
    private var taps: [ProcessTap] = []

    public init(outputUID: String) {
        self.outputUID = outputUID
    }

    public var tapCount: Int { taps.count }

    /// Changes the taps carried by this engine. Slot index = array order.
    ///
    /// The aggregate device is destroyed and recreated when the tap list changes.
    ///
    /// Live writes to `kAudioAggregateDevicePropertyTapList` were tested as well. The call succeeds,
    /// but the device then gives the IOProc **zero input buffers**, silently cutting all audio.
    /// Recreating the device leaves a millisecond-scale gap when an application starts playing,
    /// which is already a natural transition and preferable to permanent silence.
    ///
    /// If the list is unchanged, only gains are updated and CoreAudio objects remain untouched.
    public func setTaps(_ newTaps: [ProcessTap], gains: [Float]) throws {
        guard newTaps.count <= MixerSlots.capacity else {
            throw CAError(status: kAudioHardwareIllegalOperationError, what: "slot capacity exceeded")
        }
        let unchanged = taps.map(\.uuid) == newTaps.map(\.uuid)
        if unchanged, ioProcID != nil {
            for (slot, gain) in gains.enumerated() where slot < taps.count {
                slots.setGain(gain, slot: slot)
            }
            return
        }

        stop()
        destroyDevice()
        taps = newTaps

        guard !taps.isEmpty else { return }
        for (slot, gain) in gains.enumerated() where slot < taps.count {
            slots.reset(slot: slot, gain: gain)
        }
        try createDevice()
        try start()
    }

    // MARK: - Aggregate device

    private func tapListValue() -> [[String: Any]] {
        taps.map { [kAudioSubTapUIDKey: $0.tapUID] }
    }

    private func createDevice() throws {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Volumix Mixer",
            kAudioAggregateDeviceUIDKey: "com.volumix.aggregate.\(outputUID)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,      // Keep it out of system audio settings.
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: tapListValue(),
        ]
        var id = AudioObjectID.unknown
        try caCheck(
            AudioHardwareCreateAggregateDevice(description as CFDictionary, &id),
            "create aggregate device (\(outputUID))"
        )
        deviceID = id
    }

    private func destroyDevice() {
        guard deviceID != .unknown else { return }
        AudioHardwareDestroyAggregateDevice(deviceID)
        deviceID = .unknown
    }

    // MARK: - IOProc

    private func start() throws {
        guard deviceID != .unknown, ioProcID == nil else { return }

        // Capture only trivial pointers. Capturing a class reference would introduce ARC traffic
        // on the audio thread. See rule 1 in CLAUDE.md.
        let target = slots.target
        let current = slots.current
        let level = slots.level
        let info = slots.info

        var proc: AudioDeviceIOProcID?
        try caCheck(
            AudioDeviceCreateIOProcIDWithBlock(&proc, deviceID, nil) { _, inputData, _, outputData, _ in
                mixBlock(input: inputData, output: outputData,
                         target: target, current: current, level: level, info: info)
            },
            "create IOProc"
        )
        do {
            try caCheck(AudioDeviceStart(deviceID, proc), "start IOProc")
        } catch {
            if let proc { AudioDeviceDestroyIOProcID(deviceID, proc) }
            throw error
        }
        ioProcID = proc
    }

    private func stop() {
        guard let proc = ioProcID, deviceID != .unknown else { return }
        AudioDeviceStop(deviceID, proc)
        AudioDeviceDestroyIOProcID(deviceID, proc)
        ioProcID = nil
    }

    /// Taps are not invalidated here; the caller owns them (see `MixerController`).
    public func invalidate() {
        stop()
        destroyDevice()
        taps = []
    }

    deinit { invalidate() }
}
