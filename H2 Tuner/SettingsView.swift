import SwiftUI

// MARK: - Main Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var vpnManager: VPNManager
    @Binding var toast: ToastMessage?

    @State private var connectionExpanded = true
    @State private var routingExpanded    = true
    @State private var logsExpanded       = false
    @State private var aboutExpanded      = false
    @State private var appeared           = false
    @FocusState private var dnsCustomFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerBar
                    .padding(.top, 60).padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)

                // Connection card
                ExpandableCard(
                    title: "Подключение", icon: "network",
                    accentColor: Color(hex: "#7C5CFC"),
                    isExpanded: $connectionExpanded
                ) { connectionContent }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 30)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)

                // Routing card
                ExpandableCard(
                    title: "Маршрутизация", icon: "arrow.triangle.branch",
                    accentColor: Color(hex: "#5CF0FC"),
                    isExpanded: $routingExpanded
                ) { routingContent }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 30)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

                // Logs card
                ExpandableCard(
                    title: "Логирование", icon: "doc.text",
                    accentColor: Color(hex: "#FCA85C"),
                    isExpanded: $logsExpanded
                ) { logsContent }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 30)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)

                // About card
                ExpandableCard(
                    title: "О приложении", icon: "info.circle",
                    accentColor: Color(hex: "#5CFC8A"),
                    isExpanded: $aboutExpanded
                ) { aboutContent }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 30)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
        }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack {
            Text("Настройки")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, Color(hex: "#AAAACC")], startPoint: .leading, endPoint: .trailing)
                )
            Spacer()
        }
    }

    // MARK: - Connection Section

    private var connectionContent: some View {
        VStack(spacing: 0) {
            AnimatedToggleRow(title: "Автоподключение", subtitle: "При запуске приложения",
                icon: "bolt.fill", iconColor: Color(hex: "#FCA85C"), value: $settings.autoConnect)
            SDivider()
            AnimatedToggleRow(title: "Multiplexing (Mux)", subtitle: "Объединять соединения в один поток",
                icon: "arrow.triangle.merge", iconColor: Color(hex: "#5CF0FC"), value: $settings.enableMux)
            SDivider()
            AnimatedToggleRow(title: "Traffic Sniffing", subtitle: "Определять HTTP / TLS / QUIC трафик",
                icon: "eye.fill", iconColor: Color(hex: "#7C5CFC"), value: $settings.sniffEnabled)
        }
    }

    // MARK: - Routing Section

    private var routingContent: some View {
        VStack(spacing: 0) {

            // DNS Server picker
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    SettingIcon(icon: "server.rack", color: Color(hex: "#FC5C7D"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DNS Server").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        Text(settings.dnsMode.label).font(.system(size: 11)).foregroundColor(Color(hex: "#8A9BB8"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.top, 12)

                // DNS Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DNSMode.allCases) { mode in
                            DNSChip(mode: mode, isSelected: settings.dnsMode == mode) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    settings.dnsMode = mode
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }

                // Custom DNS input (only when custom selected)
                if settings.dnsMode == .custom {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil").font(.system(size: 12)).foregroundColor(Color(hex: "#FCA85C"))
                        TextField("192.168.1.1", text: $settings.dnsCustomValue)
                            .font(.system(size: 13, design: .monospaced)).foregroundColor(.white)
                            .keyboardType(.decimalPad).focused($dnsCustomFocused)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Готово") { dnsCustomFocused = false }
                                        .foregroundColor(Color(hex: "#5CF0FC")).fontWeight(.semibold)
                                }
                            }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color(hex: "#111120"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#FCA85C").opacity(0.4), lineWidth: 1))
                    .padding(.horizontal, 14)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }
            }
            .padding(.bottom, 12)

            SDivider()

            // Routing Mode
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    SettingIcon(icon: "arrow.triangle.branch", color: Color(hex: "#5CF0FC"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Routing Mode").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        Text(settings.routingMode.subtitle).font(.system(size: 11)).foregroundColor(Color(hex: "#8A9BB8")).lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.top, 12)

                // Routing mode cards
                VStack(spacing: 8) {
                    ForEach(RoutingMode.allCases) { mode in
                        RoutingModeRow(mode: mode, isSelected: settings.routingMode == mode) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                settings.routingMode = mode
                                // Auto-disable bypassLan in direct mode
                                if mode == .direct { settings.bypassLan = false }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)

                // Bypass RU domains preview (only in bypassRu mode)
                if settings.routingMode == .bypassRu {
                    BypassDomainsPreview()
                        .padding(.horizontal, 14)
                        .transition(.asymmetric(
                            insertion: .push(from: .top).combined(with: .opacity),
                            removal: .push(from: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .padding(.bottom, 12)
            .animation(.spring(response: 0.35), value: settings.routingMode)

            SDivider()

            // Bypass LAN toggle
            AnimatedToggleRow(
                title: "Bypass LAN",
                subtitle: settings.routingMode == .direct ? "Недоступно в режиме Direct" : "Локальные адреса — напрямую",
                icon: "house.fill",
                iconColor: settings.routingMode == .direct ? Color(hex: "#444460") : Color(hex: "#5CFC8A"),
                value: $settings.bypassLan,
                disabled: settings.routingMode == .direct
            )
        }
        .animation(.spring(response: 0.3), value: settings.dnsMode)
    }

    // MARK: - Logs Section

    private var logsContent: some View {
        HStack(spacing: 14) {
            SettingIcon(icon: "list.bullet", color: Color(hex: "#FCA85C"))
            Text("Уровень логов").font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            Spacer()
            Picker("", selection: $settings.logLevel) {
                ForEach(["none","debug","info","warning","error"], id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu).accentColor(Color(hex: "#FCA85C"))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - About Section

    private var aboutContent: some View {
        VStack(spacing: 0) {
            aboutRow("Приложение", "H2 Tuner")
            SDivider()
            aboutRow("Xray-core", "v26.3.27")
            SDivider()
            aboutRow("Протоколы", "VLESS · VMess · Trojan · SS · Hy2")
            SDivider()
            Button {
                vpnManager.fetchRealIP()
                withAnimation { toast = ToastMessage(text: "Обновление IP...", style: .info) }
            } label: {
                HStack(spacing: 14) {
                    SettingIcon(icon: "arrow.clockwise", color: Color(hex: "#5CF0FC"))
                    Text("Обновить реальный IP").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "#5CF0FC"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Color(hex: "#444460"))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
        }
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundColor(Color(hex: "#8A9BB8"))
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "#5A5A7A"))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

// MARK: - DNS Chip

struct DNSChip: View {
    let mode: DNSMode
    let isSelected: Bool
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2)) { pressed = false }
            }
            action()
        }) {
            HStack(spacing: 5) {
                Text(mode.icon).font(.system(size: 13))
                Text(mode.label).font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color(hex: "#8A9BB8"))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                ZStack {
                    Capsule().fill(isSelected ? Color(hex: "#5CF0FC").opacity(0.18) : Color(hex: "#1A1A2E"))
                    if isSelected {
                        Capsule().strokeBorder(
                            LinearGradient(colors: [Color(hex: "#5CF0FC"), Color(hex: "#7C5CFC")], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1.5
                        )
                    } else {
                        Capsule().strokeBorder(Color(hex: "#2A2A3E"), lineWidth: 1)
                    }
                }
            )
            .scaleEffect(pressed ? 0.93 : (isSelected ? 1.03 : 1.0))
            .shadow(color: isSelected ? Color(hex: "#5CF0FC").opacity(0.25) : .clear, radius: 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Routing Mode Row

struct RoutingModeRow: View {
    let mode: RoutingMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(mode.color.opacity(isSelected ? 0.22 : 0.08))
                    Image(systemName: mode.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isSelected ? mode.color : Color(hex: "#666680"))
                }
                .frame(width: 38, height: 38)
                .shadow(color: isSelected ? mode.color.opacity(0.3) : .clear, radius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label).font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : Color(hex: "#8A9BB8"))
                    Text(mode.subtitle).font(.system(size: 11))
                        .foregroundColor(isSelected ? mode.color.opacity(0.8) : Color(hex: "#444460"))
                }

                Spacer()

                ZStack {
                    Circle().strokeBorder(isSelected ? mode.color : Color(hex: "#333350"), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle().fill(mode.color).frame(width: 10, height: 10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mode.color.opacity(0.06) : Color(hex: "#111120"))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? mode.color.opacity(0.3) : Color(hex: "#1E1E30"), lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}

// MARK: - Bypass Domains Preview

struct BypassDomainsPreview: View {
    @State private var expanded = false
    private let preview = ["sberbank.ru", "vtb.ru", "tinkoff.ru", "gosuslugi.ru", "vk.com"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle").font(.system(size: 11)).foregroundColor(Color(hex: "#FC5C7D"))
                    Text("\(ruBypassDomains.count) доменов — прямой доступ")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#FC5C7D"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(Color(hex: "#FC5C7D"))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(preview, id: \.self) { domain in
                        Text("• \(domain)").font(.system(size: 10, design: .monospaced)).foregroundColor(Color(hex: "#666680"))
                    }
                    Text("• …и ещё \(ruBypassDomains.count - preview.count)").font(.system(size: 10)).foregroundColor(Color(hex: "#444460"))
                }
                .padding(10)
                .background(Color(hex: "#111120")).clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.asymmetric(insertion: .push(from: .top).combined(with: .opacity), removal: .push(from: .bottom).combined(with: .opacity)))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Expandable Card

struct ExpandableCard<Content: View>: View {
    let title: String; let icon: String; let accentColor: Color
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { isExpanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accentColor.opacity(isExpanded ? 0.22 : 0.12))
                            .frame(width: 38, height: 38)
                            .animation(.spring(response: 0.3), value: isExpanded)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(accentColor)
                            .scaleEffect(isExpanded ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3), value: isExpanded)
                    }
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accentColor.opacity(0.8))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.35), value: isExpanded)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Rectangle().fill(accentColor.opacity(0.15)).frame(height: 1)
                    .transition(.opacity)
                content
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#1A1A2E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isExpanded ? accentColor.opacity(0.35) : Color(hex: "#242438"), lineWidth: 1)
                )
                .shadow(color: isExpanded ? accentColor.opacity(0.08) : .clear, radius: 12)
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isExpanded)
    }
}

// MARK: - Animated Toggle Row

struct AnimatedToggleRow: View {
    let title: String; let subtitle: String; let icon: String; let iconColor: Color
    @Binding var value: Bool
    var disabled: Bool = false
    @State private var wasChanged = false

    var body: some View {
        HStack(spacing: 14) {
            SettingIcon(icon: icon, color: disabled ? Color(hex: "#444460") : iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium))
                    .foregroundColor(disabled ? Color(hex: "#555570") : .white)
                Text(subtitle).font(.system(size: 11))
                    .foregroundColor(Color(hex: disabled ? "#333348" : "#666680"))
            }
            Spacer()
            Toggle("", isOn: $value)
                .labelsHidden()
                .tint(iconColor)
                .disabled(disabled)
                .onChange(of: value) { _, _ in
                    withAnimation(.spring(response: 0.2)) { wasChanged = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { wasChanged = false }
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(wasChanged ? iconColor.opacity(0.04) : Color.clear)
        .animation(.spring(response: 0.25), value: wasChanged)
    }
}

// MARK: - Helper views

struct SettingIcon: View {
    let icon: String; let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15))
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
        }
        .frame(width: 36, height: 36)
    }
}

struct SDivider: View {
    var body: some View {
        Rectangle().fill(Color(hex: "#242438")).frame(height: 1).padding(.leading, 52)
    }
}

// Legacy SettingsSection for ToolkitView
struct SettingsSection<Content: View>: View {
    let title: String; let icon: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "#8A9BB8"))
                Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "#8A9BB8")).kerning(0.8)
            }.padding(.leading, 4)
            VStack(spacing: 0) { content }
                .background(Color(hex: "#1A1A2E")).clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#2A2A3E"), lineWidth: 1))
        }
    }
}

struct SettingsToggleRow: View {
    let title: String; let subtitle: String; let icon: String; let iconColor: Color
    @Binding var value: Bool
    var body: some View {
        HStack(spacing: 14) {
            SettingIcon(icon: icon, color: iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 11)).foregroundColor(Color(hex: "#666680"))
            }
            Spacer()
            Toggle("", isOn: $value).labelsHidden().tint(iconColor)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
