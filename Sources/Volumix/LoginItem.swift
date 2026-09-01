import ServiceManagement

/// Launch at login. `SMAppService` stores the state, so no separate persistence is needed.
enum LoginItem {
    static var enabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }
}
