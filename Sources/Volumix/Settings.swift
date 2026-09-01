import Foundation

/// Persistent per-application settings keyed by bundle identifier.
struct AppSetting: Codable, Equatable {
    var gain: Float = 1
    var muted: Bool = false
    /// nil = follow the system default output.
    var outputUID: String?
}

/// A thin layer over UserDefaults. There is no separate file format, migration, or observer;
/// this type only reads and writes a dictionary.
struct Settings {
    private static let key = "appSettings"
    private var storage: [String: AppSetting]

    init() {
        let data = UserDefaults.standard.data(forKey: Self.key) ?? Data()
        storage = (try? JSONDecoder().decode([String: AppSetting].self, from: data)) ?? [:]
    }

    subscript(bundleID: String) -> AppSetting {
        get { storage[bundleID] ?? AppSetting() }
        set {
            storage[bundleID] = newValue
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
