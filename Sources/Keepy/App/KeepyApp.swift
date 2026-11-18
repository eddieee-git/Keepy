import SwiftUI

@main
struct KeepyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(Prefs.Key.isPaused) private var isPaused = false

    var body: some Scene {
        MenuBarExtra("Keepy", systemImage: isPaused ? "pause.circle" : "doc.on.clipboard") {
            MenuContent(store: AppCore.shared.store)
        }
        Settings {
            SettingsView(store: AppCore.shared.store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        AppCore.shared.start()
    }

    /// keepy://show — 다른 도구(단축어, Raycast 등)에서 패널을 엽니다.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "keepy" {
            switch url.host {
            case "show", nil: AppCore.shared.showPanel()
            default: break
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppCore.shared.store.saveNow()
    }
}
