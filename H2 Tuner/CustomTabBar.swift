import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @State private var tabScale: [AppTab: CGFloat] = [:]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabItem(tab: tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: "#111120").opacity(0.95))
                    .blur(radius: 0)
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#2A2A4A"), Color(hex: "#1A1A30")],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.5), radius: 20, y: -4)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(Color.clear)
    }

    private func tabItem(tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
                tabScale[tab] = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2)) {
                    tabScale[tab] = 1.0
                }
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accentForTab(tab).opacity(0.18))
                            .frame(width: 44, height: 32)
                    }
                    Image(systemName: tab.rawValue)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? accentForTab(tab) : Color(hex: "#444460"))
                        .shadow(color: isSelected ? accentForTab(tab).opacity(0.6) : Color.clear, radius: 6)
                        .scaleEffect(tabScale[tab] ?? 1.0)
                }
                .frame(width: 44, height: 32)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? accentForTab(tab) : Color(hex: "#333350"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func accentForTab(_ tab: AppTab) -> Color {
        switch tab {
        case .home: return Color(hex: "#7C5CFC")
        case .servers: return Color(hex: "#5CF0FC")
        case .logs: return Color(hex: "#FCA85C")
        case .settings: return Color(hex: "#5CFC8A")
        }
    }
}
