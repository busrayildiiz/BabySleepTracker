import SwiftUI

@main
struct BabySleepTrackerApp: App {
    @AppStorage("appAppearance") private var appAppearance: String = "system"

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil // sistem ayarına uy
        }
    }
}
