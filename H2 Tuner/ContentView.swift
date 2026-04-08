import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var vpnManager: VPNManager
    @State private var selectedTab: AppTab = .home
    @State private var toastMessage: ToastMessage? = nil
    @State private var previousTab: AppTab = .home
    @Namespace private var tabNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            ZStack {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    tabContent(tab)
                        .opacity(selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(selectedTab == tab)
                        .scaleEffect(selectedTab == tab ? 1 : 0.97)
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selectedTab)
                }
            }
            .padding(.bottom, 80)

            CustomTabBar(selectedTab: $selectedTab)

            // Toast
            if let toast = toastMessage {
                ToastView(message: toast)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
                    .zIndex(100)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .top).combined(with: .opacity)
                    ))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.spring(response: 0.4)) { toastMessage = nil }
                        }
                    }
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.35), value: toastMessage?.id)
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .home:    HomeView(toast: $toastMessage)
        case .servers: ServersView(toast: $toastMessage)
        case .toolkit: ToolkitView(toast: $toastMessage)
        case .logs:    LogsView()
        case .settings: SettingsView(toast: $toastMessage)
        }
    }
}
