import StanokKit
import SwiftUI

@main
struct StanokApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsWindow()
        }
    }
}
