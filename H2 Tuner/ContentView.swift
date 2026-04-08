import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var vpnManager: VPNManager
    @State private var selectedTab: AppTab = .home
    @State private var toastMessage: ToastMessage? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            ZStack {
                HomeView(toast: $toastMessage)
                    .opacity(selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .home)

                ServersView(toast: $toastMessage)
                    .opacity(selectedTab == .servers ? 1 : 0)
                    .allowsHitTesting(selectedTab == .servers)

                LogsView()
                    .opacity(selectedTab == .logs ? 1 : 0)
                    .allowsHitTesting(selectedTab == .logs)

                SettingsView(toast: $toastMessage)
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .padding(.bottom, 80)

            CustomTabBar(selectedTab: $selectedTab)

            if let toast = toastMessage {
                ToastView(message: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.spring()) {
                                toastMessage = nil
                            }
                        }
                    }
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.3), value: toastMessage?.id)
    }
}
