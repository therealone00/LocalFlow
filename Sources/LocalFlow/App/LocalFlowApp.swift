import SwiftUI

@main
struct LocalFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // LocalFlow runs as a menu bar agent, so `AppDelegate` owns the real
        // Settings and Onboarding windows. This scene exists only because an
        // `App` requires one; routing it here would create a second, competing
        // settings window.
        Settings {
            EmptyView()
        }
    }
}
