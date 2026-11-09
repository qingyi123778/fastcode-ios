import SwiftUI

@main
struct FastCodeApp: App {
    @StateObject private var prefs = Prefs.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(prefs)
                .preferredColorScheme(prefs.darkMode ? .dark : .light)
        }
    }
}
