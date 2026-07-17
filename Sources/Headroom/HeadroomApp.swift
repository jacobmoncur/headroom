import SwiftUI
import HeadroomCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct HeadroomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 680)
                .task { await model.start() }
        }
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scan Now") { model.scan() }.keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra {
            MenuBarView().environmentObject(model)
        } label: {
            Label(model.menuBarLabel, systemImage: model.health.isHealthy ? "gauge.with.dots.needle.50percent" : "exclamationmark.triangle.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(model).frame(width: 560, height: 720)
        }
    }
}
