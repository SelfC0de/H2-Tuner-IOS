import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var vpnManager: VPNManager
    @Binding var toast: ToastMessage?
    @FocusState private var dnsFieldFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                headerBar
                    .padding(.top, 60)
                    .padding(.horizontal, 20)

                connectionSection

                routingSection

                logsSection

                aboutSection

                Spacer(minLength: 40)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Настройки")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var connectionSection: some View {
        SettingsSection(title: "Подключение", icon: "network") {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    title: "Автоподключение",
                    subtitle: "При запуске приложения",
                    icon: "bolt.fill",
                    iconColor: Color(hex: "#FCA85C"),
                    value: $settings.autoConnect
                )
                Divider().background(Color(hex: "#2A2A3E")).padding(.leading, 52)

                SettingsToggleRow(
                    title: "Multiplexing (Mux)",
                    subtitle: "Объединять соединения",
                    icon: "arrow.triangle.merge",
                    iconColor: Color(hex: "#5CF0FC"),
                    value: $settings.enableMux
                )
                Divider().background(Color(hex: "#2A2A3E")).padding(.leading, 52)

                SettingsToggleRow(
                    title: "Traffic Sniffing",
                    subtitle: "Определять HTTP/TLS/QUIC трафик",
                    icon: "eye.fill",
                    iconColor: Color(hex: "#7C5CFC"),
                    value: $settings.sniffEnabled
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var routingSection: some View {
        SettingsSection(title: "Маршрутизация", icon: "arrow.triangle.branch") {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    title: "Обход локальных адресов",
                    subtitle: "LAN, loopback через direct",
                    icon: "house.fill",
                    iconColor: Color(hex: "#5CFC8A"),
                    value: $settings.bypassLocal
                )
                Divider().background(Color(hex: "#2A2A3E")).padding(.leading, 52)

                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#FC5C7D").opacity(0.15))
                        Image(systemName: "server.rack")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#FC5C7D"))
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DNS сервер")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Text("IP-адрес DNS резолвера")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#666680"))
                    }

                    Spacer()

                    TextField("1.1.1.1", text: $settings.dnsServer)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "#5CF0FC"))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($dnsFieldFocused)
                        .frame(width: 110)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Готово") { dnsFieldFocused = false }
                                    .foregroundColor(Color(hex: "#5CF0FC"))
                                    .fontWeight(.semibold)
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 20)
    }

    private var logsSection: some View {
        SettingsSection(title: "Логирование", icon: "doc.text") {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#8A9BB8").opacity(0.15))
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#8A9BB8"))
                    }
                    .frame(width: 36, height: 36)

                    Text("Уровень логов")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Picker("", selection: $settings.logLevel) {
                        Text("none").tag("none")
                        Text("debug").tag("debug")
                        Text("info").tag("info")
                        Text("warning").tag("warning")
                        Text("error").tag("error")
                    }
                    .pickerStyle(.menu)
                    .accentColor(Color(hex: "#7C5CFC"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 20)
    }

    private var aboutSection: some View {
        SettingsSection(title: "О приложении", icon: "info.circle") {
            VStack(spacing: 0) {
                aboutRow(title: "Приложение", value: "H2 Tuner")
                Divider().background(Color(hex: "#2A2A3E")).padding(.leading, 52)
                aboutRow(title: "Xray-core", value: "v26.3.27")
                Divider().background(Color(hex: "#2A2A3E")).padding(.leading, 52)
                aboutRow(title: "Протоколы", value: "VLESS · VMess · Trojan · SS · Hy2")
                Divider().background(Color(hex: "#2A2A3E")).padding(.leading, 52)
                aboutRow(title: "Минимум iOS", value: "17.0")

                Divider().background(Color(hex: "#2A2A3E")).padding(.leading, 52)

                Button {
                    vpnManager.fetchRealIP()
                    withAnimation { toast = ToastMessage(text: "Обновляем IP...", style: .info) }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#5CF0FC").opacity(0.15))
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#5CF0FC"))
                        }
                        .frame(width: 36, height: 36)

                        Text("Обновить реальный IP")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#5CF0FC"))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#8A9BB8"))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#5A5A7A"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#8A9BB8"))
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#8A9BB8"))
                    .kerning(0.8)
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Color(hex: "#1A1A2E"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#2A2A3E"), lineWidth: 1)
            )
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var value: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#666680"))
            }

            Spacer()

            Toggle("", isOn: $value)
                .labelsHidden()
                .tint(iconColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
