import CoreAudio
import Foundation

/// A tap that captures process output and disconnects it from its original route.
///
/// With `.mutedWhenTapped`, audio flows *only* through this mixer, which makes it controllable.
/// The tradeoff is responsibility for that application's audio while this object lives. If the
/// process exits without `invalidate()`, its audio is lost. See rule 2 in CLAUDE.md.
public final class ProcessTap {
    /// One tap groups all processes for an application, including render and GPU helpers.
    public let processIDs: [AudioObjectID]
    public let uuid: UUID
    public private(set) var tapID: AudioObjectID = .unknown

    public init(processes: [AudioObjectID], label: String) throws {
        processIDs = processes
        uuid = UUID()

        let description = CATapDescription(stereoMixdownOfProcesses: processes)
        description.uuid = uuid
        description.name = "Volumix – \(label)"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped

        var id = AudioObjectID.unknown
        try caCheck(AudioHardwareCreateProcessTap(description, &id), "create tap (\(label))")
        guard id != .unknown else {
            throw CAError(status: kAudioHardwareBadObjectError, what: "tap returned an invalid ID")
        }
        tapID = id
    }

    /// Identifier used in the aggregate device's tap list.
    public var tapUID: String { uuid.uuidString }

    public var format: AudioStreamBasicDescription? {
        try? tapID.read(.address(kAudioTapPropertyFormat), as: AudioStreamBasicDescription.self)
    }

    public func invalidate() {
        guard tapID != .unknown else { return }
        AudioHardwareDestroyProcessTap(tapID)
        tapID = .unknown
    }

    deinit { invalidate() }
}

public extension AudioObjectID {
    static let unknown = AudioObjectID(kAudioObjectUnknown)
}
