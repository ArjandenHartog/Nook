import SwiftUI

@main
struct NookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Nook heeft geen gewoon venster; alles gebeurt in de notch en het menubalk-icoon.
        Settings {
            SettingsView().environmentObject(AppModel.shared)
        }
    }
}
