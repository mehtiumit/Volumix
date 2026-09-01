import CoreAudio
import Foundation

/// An audio-producing process known to CoreAudio.
public struct AudioProcess: Identifiable, Hashable, Sendable {
    /// macOS owns these transient audio producers. Tapping them would rebuild the aggregate device
    /// when an alert starts and again when it ends, interrupting every application already mixed.
    private static let systemPassthroughBundleIDs: Set<String> = [
        "systemsoundserverd",
    ]

    static func shouldPassThroughSystemAudio(bundleID: String) -> Bool {
        systemPassthroughBundleIDs.contains(bundleID)
    }

    public let id: AudioObjectID
    public let pid: pid_t
    public let bundleID: String
    public let isRunningOutput: Bool

    init(id: AudioObjectID) {
        self.id = id
        // `as:` is required: in a `try? … ?? default` expression Swift may infer T as Optional,
        // which silently weakens the size check.
        pid = (try? id.read(.address(kAudioProcessPropertyPID), as: pid_t.self)) ?? -1
        bundleID = (try? id.readString(.address(kAudioProcessPropertyBundleID))) ?? ""
        isRunningOutput = ((try? id.read(.address(kAudioProcessPropertyIsRunningOutput),
                                         as: UInt32.self)) ?? 0) != 0
    }

    public static func all() throws -> [AudioProcess] {
        try AudioObjectID.system
            .readArray(.address(kAudioHardwarePropertyProcessObjectList), of: AudioObjectID.self)
            .map(AudioProcess.init(id:))
    }

    /// Processes currently producing output audio—the ones shown in the mixer.
    public static func playing() throws -> [AudioProcess] {
        try all().filter {
            $0.isRunningOutput
                && !$0.bundleID.isEmpty
                && !shouldPassThroughSystemAudio(bundleID: $0.bundleID)
        }
    }
}

public enum AudioDevices {
    public static var defaultOutputID: AudioObjectID {
        get throws {
            try AudioObjectID.system.read(.address(kAudioHardwarePropertyDefaultOutputDevice))
        }
    }

    public static func uid(of device: AudioObjectID) throws -> String {
        try device.readString(.address(kAudioDevicePropertyDeviceUID))
    }

    public static func name(of device: AudioObjectID) throws -> String {
        try device.readString(.address(kAudioObjectPropertyName))
    }

    public static var defaultOutputUID: String {
        get throws { try uid(of: defaultOutputID) }
    }

    /// The device's main output volume (0...1).
    ///
    /// Some devices expose one master element; others expose only per-channel levels.
    /// For the latter, use the left channel as the representative value because the panel has one slider.
    private static func volumeAddresses(_ device: AudioObjectID) -> [AudioObjectPropertyAddress] {
        [0, 1, 2].map {
            .address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, $0)
        }
    }

    public static func volume(of device: AudioObjectID) -> Float? {
        for address in volumeAddresses(device) where device.has(address) {
            if let value = try? device.read(address, as: Float32.self) { return value }
        }
        return nil
    }

    public static func setVolume(_ volume: Float, of device: AudioObjectID) {
        let clamped = max(0, min(1, volume))
        // A master element is sufficient when available; otherwise write each channel separately.
        let master = volumeAddresses(device)[0]
        if device.has(master), (try? device.write(master, Float32(clamped))) != nil { return }
        for address in volumeAddresses(device).dropFirst() where device.has(address) {
            try? device.write(address, Float32(clamped))
        }
    }

    /// All devices that expose output channels.
    public static func outputs() throws -> [(id: AudioObjectID, name: String, uid: String)] {
        try AudioObjectID.system
            .readArray(.address(kAudioHardwarePropertyDevices), of: AudioObjectID.self)
            .filter { device in
                let streams = try? device.readArray(
                    .address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput),
                    of: AudioObjectID.self
                )
                return !(streams ?? []).isEmpty
            }
            .compactMap { device in
                guard let name = try? name(of: device), let uid = try? uid(of: device) else { return nil }
                return (device, name, uid)
            }
    }
}
