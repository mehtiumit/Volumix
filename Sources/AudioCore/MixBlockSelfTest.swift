import CoreAudio
import Foundation

/// Channel/frame arithmetic is the one place where `mixBlock` can fail silently.
/// Verify it with synthetic buffers and no audio hardware: `swift run spike --test`.
public func mixBlockSelfTest() {
    assert(AudioProcess.shouldPassThroughSystemAudio(bundleID: "systemsoundserverd"),
           "system sounds must bypass the process tap graph")
    assert(!AudioProcess.shouldPassThroughSystemAudio(bundleID: "com.spotify.client"),
           "regular applications must remain eligible for process taps")

    let frames = 512

    func makeList(buffers: Int, channels: Int, fill: Float) -> UnsafeMutableAudioBufferListPointer {
        let list = AudioBufferList.allocate(maximumBuffers: buffers)
        for index in 0..<buffers {
            let count = frames * channels
            let data = UnsafeMutablePointer<Float>.allocate(capacity: count)
            data.initialize(repeating: fill, count: count)
            list[index] = AudioBuffer(
                mNumberChannels: UInt32(channels),
                mDataByteSize: UInt32(count * MemoryLayout<Float>.size),
                mData: UnsafeMutableRawPointer(data)
            )
        }
        return list
    }

    func run(inputBuffers: Int, inputChannels: Int, outputBuffers: Int, outputChannels: Int,
             gain: Float) -> (out: [Float], level: Float) {
        let input = makeList(buffers: inputBuffers, channels: inputChannels, fill: 1)
        let output = makeList(buffers: outputBuffers, channels: outputChannels, fill: 99)
        let slots = MixerSlots()
        slots.reset(slot: 0, gain: gain)

        mixBlock(input: UnsafePointer(input.unsafeMutablePointer),
                 output: output.unsafeMutablePointer,
                 target: slots.target, current: slots.current,
                 level: slots.level, info: slots.info)

        let first = output[0]
        let samples = Array(UnsafeBufferPointer(
            start: first.mData!.assumingMemoryBound(to: Float.self),
            count: frames * outputChannels
        ))
        let level = slots.level[0]
        for buffer in input { buffer.mData?.deallocate() }
        for buffer in output { buffer.mData?.deallocate() }
        return (samples, level)
    }

    // Typical path: interleaved stereo tap → interleaved stereo device.
    var result = run(inputBuffers: 1, inputChannels: 2, outputBuffers: 1, outputChannels: 2, gain: 0.5)
    assert(abs(result.out[0] - 0.5) < 0.001, "gain was not applied: \(result.out[0])")
    assert(abs(result.out[frames * 2 - 1] - 0.5) < 0.001, "last frame was not written")
    assert(abs(result.level - 1.0) < 0.001, "level was measured after gain: \(result.level)")

    // Silence: zero gain must clear the output completely, with no stale content (99) leaking through.
    result = run(inputBuffers: 1, inputChannels: 2, outputBuffers: 1, outputChannels: 2, gain: 0)
    assert(result.out.allSatisfy { abs($0) < 0.001 }, "mute leaked audio: \(result.out[0])")

    // Non-interleaved device: two buffers × one channel. Global channel tracking must work.
    result = run(inputBuffers: 1, inputChannels: 2, outputBuffers: 2, outputChannels: 1, gain: 1)
    assert(abs(result.out[0] - 1.0) < 0.001, "non-interleaved left channel was not written")

    // More output channels than input channels (for example 5.1) must not overflow.
    result = run(inputBuffers: 1, inputChannels: 2, outputBuffers: 1, outputChannels: 6, gain: 1)
    assert(abs(result.out[0] - 1.0) < 0.001, "front-left channel is empty on multichannel output")
    assert(abs(result.out[2]) < 0.001, "stereo source leaked into an extra channel")

    print("AudioCore: system sound filter and 4 mix scenarios passed")
}
