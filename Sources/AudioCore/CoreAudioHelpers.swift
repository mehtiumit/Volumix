import CoreAudio
import Foundation

public struct CAError: LocalizedError {
    public let status: OSStatus
    public let what: String

    public var errorDescription: String? {
        // OSStatus values are often four-character codes ('!obj', 'nope'); make them readable.
        let chars = [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: status >> $0) }
        let fourCC = chars.allSatisfy { $0 >= 32 && $0 < 127 }
            ? " '" + String(decoding: chars, as: UTF8.self) + "'"
            : ""
        return "\(what) failed: \(status)\(fourCC)"
    }
}

@discardableResult
public func caCheck(_ status: OSStatus, _ what: @autoclosure () -> String) throws -> OSStatus {
    guard status == noErr else { throw CAError(status: status, what: what()) }
    return status
}

public extension AudioObjectPropertyAddress {
    /// Used as `.address(kAudio…)` at call sites; scope and element are almost always the defaults.
    static func address(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        _ element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> Self {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }
}

public extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    func has(_ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        return AudioObjectHasProperty(self, &address)
    }

    /// Raw read. The caller owns the returned buffer; the other `read*` helpers wrap this method.
    func readRaw(_ address: AudioObjectPropertyAddress) throws -> (UnsafeMutableRawPointer, UInt32) {
        var address = address
        var size: UInt32 = 0
        try caCheck(
            AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size),
            "\(address.mSelector.fourCC) size query"
        )
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
        do {
            try caCheck(
                AudioObjectGetPropertyData(self, &address, 0, nil, &size, buffer),
                "\(address.mSelector.fourCC) read"
            )
        } catch {
            buffer.deallocate()
            throw error
        }
        return (buffer, size)
    }

    func read<T>(_ address: AudioObjectPropertyAddress, as _: T.Type = T.self) throws -> T {
        let (buffer, size) = try readRaw(address)
        defer { buffer.deallocate() }
        guard size >= UInt32(MemoryLayout<T>.size) else {
            throw CAError(status: kAudioHardwareBadPropertySizeError,
                          what: "\(address.mSelector.fourCC) result smaller than expected")
        }
        return buffer.load(as: T.self)
    }

    func readArray<T>(_ address: AudioObjectPropertyAddress, of _: T.Type = T.self) throws -> [T] {
        let (buffer, size) = try readRaw(address)
        defer { buffer.deallocate() }
        let count = Int(size) / MemoryLayout<T>.size
        guard count > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: buffer.assumingMemoryBound(to: T.self), count: count))
    }

    func readString(_ address: AudioObjectPropertyAddress) throws -> String {
        let (buffer, _) = try readRaw(address)
        defer { buffer.deallocate() }
        guard let raw = buffer.load(as: CFString?.self) else { return "" }
        // CoreAudio returns CFString properties with a +1 retain count.
        return Unmanaged.passUnretained(raw).takeRetainedValue() as String
    }

    func write<T>(_ address: AudioObjectPropertyAddress, _ value: T) throws {
        var address = address
        var value = value
        _ = try withUnsafeBytes(of: &value) { bytes in
            try caCheck(
                AudioObjectSetPropertyData(self, &address, 0, nil,
                                           UInt32(bytes.count), bytes.baseAddress!),
                "\(address.mSelector.fourCC) write"
            )
        }
    }

    /// Reference-valued properties such as CFArray/CFString: CoreAudio expects the pointer itself.
    func write(_ address: AudioObjectPropertyAddress, cf value: AnyObject) throws {
        var address = address
        var reference = Unmanaged.passUnretained(value).toOpaque()
        try caCheck(
            AudioObjectSetPropertyData(self, &address, 0, nil,
                                       UInt32(MemoryLayout<UnsafeRawPointer>.size), &reference),
            "\(address.mSelector.fourCC) write"
        )
    }
}

public extension AudioObjectPropertySelector {
    var fourCC: String {
        let chars = [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: self >> UInt32($0)) }
        guard chars.allSatisfy({ $0 >= 32 && $0 < 127 }) else { return String(self) }
        return String(decoding: chars, as: UTF8.self)
    }
}
