import Foundation

/// The only data exchanged between the UI thread and the audio thread.
///
/// Contract: the UI writes only `target`/`muted` and reads only `level`; the audio thread does the
/// inverse. There are no locks or allocations. Storage is preallocated with 4-byte-aligned `Float`
/// values, whose loads and stores are indivisible on arm64 and x86-64. A race can produce at worst
/// one block of stale gain, which is inaudible.
///
/// ponytail: Capacity is fixed at 32. More than 32 simultaneous audio-producing applications
/// would require dynamic growth, which is not a realistic desktop workload.
public final class MixerSlots: @unchecked Sendable {
    public static let capacity = 32

    /// Gain requested by the UI (0...1, including mute).
    let target: UnsafeMutablePointer<Float>
    /// Current gain after ramping. Only the audio thread writes it.
    let current: UnsafeMutablePointer<Float>
    /// RMS of the latest block. The audio thread writes it and the UI reads it.
    let level: UnsafeMutablePointer<Float>
    /// Block geometry: [input buffers, output buffers, input channels, output channels, frames].
    /// Diagnostics only; this exposes values that cannot be printed from the real-time thread.
    let info: UnsafeMutablePointer<Int32>

    public init() {
        target = .allocate(capacity: Self.capacity)
        current = .allocate(capacity: Self.capacity)
        level = .allocate(capacity: Self.capacity)
        info = .allocate(capacity: 5)
        target.initialize(repeating: 1, count: Self.capacity)
        current.initialize(repeating: 1, count: Self.capacity)
        level.initialize(repeating: 0, count: Self.capacity)
        info.initialize(repeating: 0, count: 5)
    }

    deinit {
        target.deallocate()
        current.deallocate()
        level.deallocate()
        info.deallocate()
    }

    /// (input buffers, output buffers, input channels, output channels, frames)
    public var geometry: (inBuffers: Int, outBuffers: Int, inChannels: Int, outChannels: Int, frames: Int) {
        (Int(info[0]), Int(info[1]), Int(info[2]), Int(info[3]), Int(info[4]))
    }

    public func setGain(_ gain: Float, slot: Int) {
        guard slot >= 0, slot < Self.capacity else { return }
        target[slot] = max(0, min(1, gain))
    }

    public func gain(slot: Int) -> Float {
        guard slot >= 0, slot < Self.capacity else { return 0 }
        return target[slot]
    }

    public func level(slot: Int) -> Float {
        guard slot >= 0, slot < Self.capacity else { return 0 }
        return level[slot]
    }

    /// Resets a slot before reuse so the previous application's gain cannot leak into the new one.
    func reset(slot: Int, gain: Float) {
        guard slot >= 0, slot < Self.capacity else { return }
        target[slot] = gain
        current[slot] = gain
        level[slot] = 0
    }
}
