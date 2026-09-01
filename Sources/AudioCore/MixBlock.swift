import CoreAudio

/// Gain ramp coefficient. At 48 kHz it produces a ~10 ms transition that prevents zipper noise.
private let rampCoefficient: Float = 0.002

/// RT-SAFE. Mixes tap inputs with gain into the output device and measures RMS along the way.
///
/// Nothing called from here may allocate memory, acquire a lock, or send an Objective-C message.
/// Slot mapping: `input` buffer order == order in the `MixerEngine.setTaps` array.
///
/// ponytail: Assumes one buffer per tap (a stereo mixdown tap arrives interleaved).
/// Extra buffers are ignored if the buffer count exceeds the tap count; the spike tool verifies this.
@inline(__always)
func mixBlock(
    input: UnsafePointer<AudioBufferList>,
    output: UnsafeMutablePointer<AudioBufferList>,
    target: UnsafeMutablePointer<Float>,
    current: UnsafeMutablePointer<Float>,
    level: UnsafeMutablePointer<Float>,
    info: UnsafeMutablePointer<Int32>
) {
    let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
    let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))

    for buffer in outputBuffers {
        if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
    }
    info[0] = Int32(inputBuffers.count)
    info[1] = Int32(outputBuffers.count)
    guard inputBuffers.count > 0, outputBuffers.count > 0 else { return }
    info[2] = Int32(inputBuffers[0].mNumberChannels)
    info[3] = Int32(outputBuffers[0].mNumberChannels)
    info[4] = Int32(Int(outputBuffers[0].mDataByteSize)
        / max(1, MemoryLayout<Float>.size * Int(outputBuffers[0].mNumberChannels)))

    for slot in 0..<min(inputBuffers.count, MixerSlots.capacity) {
        let source = inputBuffers[slot]
        guard let sourceData = source.mData, source.mNumberChannels > 0 else { continue }

        let inChannels = Int(source.mNumberChannels)
        let inFrames = Int(source.mDataByteSize) / (MemoryLayout<Float>.size * inChannels)
        guard inFrames > 0 else { continue }

        let samples = sourceData.assumingMemoryBound(to: Float.self)
        let targetGain = target[slot]
        var gain = current[slot]
        var sumSquares: Float = 0

        // An interleaved output device provides one buffer × N channels; a non-interleaved device
        // provides N buffers × one channel. Tracking a global channel index handles both layouts.
        var globalChannel = 0
        for destination in outputBuffers {
            guard let destinationData = destination.mData, destination.mNumberChannels > 0 else { continue }
            let outChannels = Int(destination.mNumberChannels)
            let outFrames = Int(destination.mDataByteSize) / (MemoryLayout<Float>.size * outChannels)
            let frames = min(inFrames, outFrames)
            let out = destinationData.assumingMemoryBound(to: Float.self)

            gain = current[slot]
            for frame in 0..<frames {
                gain += (targetGain - gain) * rampCoefficient
                for channel in 0..<outChannels {
                    let sourceChannel = globalChannel + channel
                    guard sourceChannel < inChannels else { break }
                    out[frame * outChannels + channel] += samples[frame * inChannels + sourceChannel] * gain
                }
            }
            globalChannel += outChannels
            if globalChannel >= inChannels { break }
        }

        // Measure level *before* gain so a quieted application still shows that it is producing audio.
        let sampleCount = inFrames * inChannels
        for index in 0..<sampleCount {
            let sample = samples[index]
            sumSquares += sample * sample
        }
        current[slot] = gain
        level[slot] = (sumSquares / Float(sampleCount)).squareRoot()
    }
}
