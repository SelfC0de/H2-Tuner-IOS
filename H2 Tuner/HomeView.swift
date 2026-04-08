import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var vpnManager: VPNManager
    @Binding var toast: ToastMessage?

    @State private var linkText: String = ""
    @State private var showPasteSheet = false
    @FocusState private var linkFocused: Bool
    @State private var pulseAnimation = false
    @State private var glowAnimation = false
    @State private var rotationAnimation = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 60)

                connectionOrb
                    .padding(.top, 32)

                statusSection
                    .padding(.top, 24)

                ipSection
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                linkInputSection
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                if settings.selectedServer != nil {
                    selectedServerCard
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                }

                connectButton
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("H2 Tuner")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Xray v26.3.27")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#5CF0FC"))
            }
            Spacer()
            HStack(spacing: 8) {
                Circle()
                    .fill(vpnManager.connectionState.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: vpnManager.connectionState.color.opacity(0.8), radius: 4)
                Text(vpnManager.connectionState.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(vpnManager.connectionState.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(vpnManager.connectionState.color.opacity(0.12))
                    .overlay(Capsule().stroke(vpnManager.connectionState.color.opacity(0.3), lineWidth: 1))
            )
        }
        .padding(.horizontal, 20)
    }

    private var connectionOrb: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        orbColor.opacity(0.06 - Double(i) * 0.015),
                        lineWidth: 1
                    )
                    .frame(width: 180 + CGFloat(i * 50), height: 180 + CGFloat(i * 50))
                    .scaleEffect(pulseAnimation && vpnManager.connectionState == .connected ? 1.08 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5 + Double(i) * 0.3).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [orbColor.opacity(0.25), orbColor.opacity(0.05), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [orbColor.opacity(0.9), orbColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: orbColor.opacity(0.6), radius: glowAnimation ? 30 : 15)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: glowAnimation)

            Image(systemName: orbIcon)
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(.white)
                .rotationEffect(.degrees(rotationAnimation && isAnimating ? 360 : 0))
                .animation(
                    isAnimating ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                    value: rotationAnimation
                )
        }
        .onAppear {
            pulseAnimation = true
            glowAnimation = true
            if isAnimating { rotationAnimation = true }
        }
        .onChange(of: vpnManager.connectionState) { _ in
            rotationAnimation = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if isAnimating { rotationAnimation = true }
            }
        }
    }

    private var isAnimating: Bool {
        vpnManager.connectionState == .connecting || vpnManager.connectionState == .disconnecting
    }

    private var orbColor: Color {
        vpnManager.connectionState.color
    }

    private var orbIcon: String {
        switch vpnManager.connectionState {
        case .connected: return "lock.shield.fill"
        case .connecting: return "arrow.trianglehead.2.clockwise"
        case .disconnecting: return "arrow.trianglehead.2.clockwise"
        case .disconnected: return "shield.fill"
        case .error: return "exclamationmark.shield.fill"
        }
    }

    private var statusSection: some View {
        VStack(spacing: 6) {
            Text(vpnManager.connectionState.label)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if vpnManager.connectionState == .connected, let since = vpnManager.connectedAt {
                ConnectionTimerView(since: since)
            }

            if vpnManager.connectionState == .connected {
                HStack(spacing: 20) {
                    trafficBadge(icon: "arrow.up", value: vpnManager.bytesUp.formattedBytes, color: Color(hex: "#5CFC8A"))
                    trafficBadge(icon: "arrow.down", value: vpnManager.bytesDown.formattedBytes, color: Color(hex: "#5CF0FC"))
                }
                .padding(.top, 4)
            }
        }
    }

    private func trafficBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
    }

    private var ipSection: some View {
        HStack(spacing: 12) {
            IPCard(
                title: "Реальный IP",
                info: vpnManager.realIP,
                icon: "wifi",
                accentColor: Color(hex: "#8A9BB8")
            )

            IPCard(
                title: "VPN IP",
                info: vpnManager.vpnIP,
                icon: "lock.shield.fill",
                accentColor: vpnManager.connectionState == .connected ? Color(hex: "#5CFC8A") : Color(hex: "#666680"),
                isEmpty: vpnManager.connectionState != .connected
            )
        }
    }

    private var linkInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ссылка подключения")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#8A9BB8"))

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#5CF0FC"))

                    TextField("vless:// vmess:// trojan:// ss:// hy2://", text: $linkText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($linkFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Готово") { linkFocused = false }
                                    .foregroundColor(Color(hex: "#5CF0FC"))
                                    .fontWeight(.semibold)
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#1A1A2E"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(linkFocused ? Color(hex: "#5CF0FC").opacity(0.5) : Color(hex: "#2A2A3E"), lineWidth: 1)
                        )
                )

                Button {
                    pasteAndParse()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#5CF0FC"))
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#1A1A2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#2A2A3E"), lineWidth: 1)
                        )
                }

                if !linkText.isEmpty {
                    Button {
                        parseLink()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#5CFC8A"))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#1A1A2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#2A2A3E"), lineWidth: 1)
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: linkText.isEmpty)
        }
    }

    private var selectedServerCard: some View {
        Group {
            if let server = settings.selectedServer {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(server.protocol.accentColor.opacity(0.15))
                        Image(systemName: server.protocol.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(server.protocol.accentColor)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("\(server.protocol.displayName) · \(server.host):\(server.port)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#8A9BB8"))
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(server.protocol.accentColor)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#1A1A2E"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(settings.selectedServer?.protocol.accentColor.opacity(0.3) ?? Color.clear, lineWidth: 1)
                        )
                )
            }
        }
    }

    private var connectButton: some View {
        Button {
            handleConnect()
        } label: {
            HStack(spacing: 12) {
                if vpnManager.connectionState == .connecting || vpnManager.connectionState == .disconnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: vpnManager.connectionState == .connected ? "stop.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                }

                Text(connectButtonLabel)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(connectButtonGradient)
                    .shadow(color: connectButtonShadow.opacity(0.4), radius: 12, y: 4)
            )
        }
        .disabled(vpnManager.connectionState == .connecting || vpnManager.connectionState == .disconnecting)
        .scaleEffect(vpnManager.connectionState == .connecting || vpnManager.connectionState == .disconnecting ? 0.97 : 1.0)
        .animation(.spring(response: 0.3), value: vpnManager.connectionState)
    }

    private var connectButtonLabel: String {
        switch vpnManager.connectionState {
        case .connected: return "Отключиться"
        case .connecting: return "Подключение..."
        case .disconnecting: return "Отключение..."
        default: return "Подключиться"
        }
    }

    private var connectButtonGradient: LinearGradient {
        switch vpnManager.connectionState {
        case .connected:
            return LinearGradient(colors: [Color(hex: "#FC5C7D"), Color(hex: "#c02040")], startPoint: .leading, endPoint: .trailing)
        case .connecting, .disconnecting:
            return LinearGradient(colors: [Color(hex: "#FCA85C"), Color(hex: "#c06020")], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [Color(hex: "#7C5CFC"), Color(hex: "#5C3CCC")], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var connectButtonShadow: Color {
        switch vpnManager.connectionState {
        case .connected: return Color(hex: "#FC5C7D")
        case .connecting, .disconnecting: return Color(hex: "#FCA85C")
        default: return Color(hex: "#7C5CFC")
        }
    }

    private func handleConnect() {
        if vpnManager.connectionState == .connected {
            vpnManager.disconnect()
        } else {
            guard let server = settings.selectedServer else {
                withAnimation { toast = ToastMessage(text: "Выберите сервер", style: .warning) }
                return
            }
            vpnManager.connect(server: server)
        }
    }

    private func pasteAndParse() {
        if let str = UIPasteboard.general.string, !str.isEmpty {
            linkText = str
            parseLink()
        } else {
            withAnimation { toast = ToastMessage(text: "Буфер обмена пуст", style: .info) }
        }
    }

    private func parseLink() {
        guard !linkText.isEmpty else { return }
        do {
            let server = try LinkParser.parse(linkText)
            settings.addServer(server)
            settings.selectedServerID = server.id
            linkText = ""
            withAnimation { toast = ToastMessage(text: "Сервер добавлен: \(server.name)", style: .success) }
        } catch {
            withAnimation { toast = ToastMessage(text: error.localizedDescription, style: .error) }
        }
    }
}

struct IPCard: View {
    let title: String
    let info: IPInfo?
    let icon: String
    let accentColor: Color
    var isEmpty: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#8A9BB8"))
            }

            if isEmpty {
                Text("—")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#444460"))
            } else if let info = info {
                Text(info.ip)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let country = info.country, let city = info.city {
                    Text("\(country) · \(city)")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#8A9BB8"))
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 4) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                        .scaleEffect(0.6)
                    Text("Загрузка...")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#666680"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#1A1A2E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(isEmpty ? 0.1 : 0.25), lineWidth: 1)
                )
        )
    }
}

struct ConnectionTimerView: View {
    let since: Date
    @State private var elapsed: String = "00:00:00"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(elapsed)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundColor(Color(hex: "#5CFC8A"))
            .onReceive(timer) { _ in
                let interval = Date().timeIntervalSince(since)
                let h = Int(interval) / 3600
                let m = Int(interval) % 3600 / 60
                let s = Int(interval) % 60
                elapsed = String(format: "%02d:%02d:%02d", h, m, s)
            }
    }
}
