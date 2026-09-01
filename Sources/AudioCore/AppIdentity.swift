import Darwin
import Foundation

/// The user-facing application that owns a process.
///
/// CoreAudio reports helper processes such as `com.brave.Browser.helper`, while the user expects
/// a single "Brave Browser" row. Resolve this by finding the **outermost** `.app` bundle in the
/// process executable path. Helpers live in nested bundles inside their main application, so this
/// is substantially more robust than maintaining a fixed list of bundle identifier suffixes.
public struct AppIdentity: Hashable, Sendable {
    public let bundleID: String
    public let name: String
    public let bundleURL: URL?

    public static func resolve(pid: pid_t, fallbackBundleID: String) -> AppIdentity {
        guard let url = outermostAppBundle(pid: pid) else {
            return AppIdentity(bundleID: fallbackBundleID,
                               name: fallbackBundleID.split(separator: ".").last.map(String.init)
                                   ?? fallbackBundleID,
                               bundleURL: nil)
        }
        let bundle = Bundle(url: url)
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return AppIdentity(bundleID: bundle?.bundleIdentifier ?? fallbackBundleID,
                           name: name,
                           bundleURL: url)
    }

    private static func outermostAppBundle(pid: pid_t) -> URL? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(MAXPATHLEN)) > 0 else { return nil }
        let path = String(cString: buffer)

        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return URL(fileURLWithPath: components[...index].joined(separator: "/"))
    }
}
