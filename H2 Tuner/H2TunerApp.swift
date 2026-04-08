import SwiftUI

@main
struct H2TunerApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var vpnManager = VPNManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(vpnManager)
                .preferredColorScheme(.dark)
        }
    }
}
