import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var vpnManager: VPNManager
    @Binding var toast: ToastMessage?

    @State private var linkText: String = ""
    @FocusState private var linkFocused: Bool
    @State private var titleWaveOffset: CGFloat = 0
    @State private var titleGlow = false
    @State private var cardPulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 56)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)

                    // Главная статус-карточка
                    statusCard
                        .padding(.horizontal, 16)

                    // IP + трафик
                    statsGrid
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    // Сервер или поле ввода
                    serverOrInputSection
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    Spacer()

                    // Отступ под кнопку
                    Spacer().frame(height: 80)
                }

                // Кнопка зафиксирована внизу
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color(hex: "#0a0a10").opacity(0), Color(hex: "#0a0a10")],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 20)
                    .allowsHitTesting(false)

                    connectButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom : 16)
                        .background(Color(hex: "#0a0a10"))
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("H2 Tuner")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#FFFFFF"), Color(hex: "#7C5CFC"), Color(hex: "#5CF0FC"), Color(hex: "#FFFFFF")],
                        startPoint: UnitPoint(x: titleWaveOffset - 0.5, y: 0),
                        endPoint: UnitPoint(x: titleWaveOffset + 0.5, y: 1)
                    )
                )
                .shadow(color: Color(hex: "#7C5CFC").opacity(titleGlow ? 0.7 : 0.15), radius: titleGlow ? 10 : 4)
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { titleWaveOffset = 1.5 }
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { titleGlow = true }
                }
            Spacer()
            // Статус пилюля
            HStack(spacing: 5) {
                Circle()
                    .fill(vpnManager.connectionState.color)
                    .frame(width: 6, height: 6)
                    .shadow(color: vpnManager.connectionState.color.opacity(0.8), radius: 3)
                if vpnManager.connectionState == .connected, let since = vpnManager.connectedAt {
                    ConnectionTimerView(since: since, color: vpnManager.connectionState.color)
                } else {
                    Text(vpnManager.connectionState.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(vpnManager.connectionState.color)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(vpnManager.connectionState.color.opacity(0.12))
                    .overlay(Capsule().stroke(vpnManager.connectionState.color.opacity(0.3), lineWidth: 1))
            )
        }
    }

    // MARK: - Status Card (главный элемент)

    private var statusCard: some View {
        let isConnected = vpnManager.connectionState == .connected
        let accent = vpnManager.connectionState.color

        return ZStack(alignment: .topTrailing) {
            // Декоративный круг фон
            Circle()
                .fill(accent.opacity(0.06))
                .frame(width: 100, height: 100)
                .offset(x: 20, y: -20)
                .clipped()

            VStack(alignment: .leading, spacing: 12) {
                // Верхняя строка: иконка + статус + сервер
                HStack(spacing: 10) {
                    // Иконка
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: orbIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(accent)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(isAnimating ? .linear(duration: 1.5).repeatForever(autoreverses: false) : .default, value: isAnimating)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vpnManager.connectionState.label)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        if let server = settings.selectedServer {
                            Text("\(server.protocol.displayName) · \(server.host)")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#8A9BB8"))
                                .lineLimit(1)
                        } else {
                            Text("Сервер не выбран")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#666680"))
                        }
                    }

                    Spacer()

                    // Индикатор активности
                    if isConnected {
                        VStack(spacing: 2) {
                            ForEach(0..<3) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(accent.opacity(0.3 + Double(i) * 0.25))
                                    .frame(width: 4, height: CGFloat(6 + i * 4))
                            }
                        }
                        .scaleEffect(x: 1, y: cardPulse ? 1.15 : 0.85, anchor: .bottom)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: cardPulse)
                        .onAppear { cardPulse = true }
                    }
                }

                if isConnected {
                    // Разделитель
                    Rectangle()
                        .fill(accent.opacity(0.15))
                        .frame(height: 0.5)

                    // Трафик строка
                    HStack(spacing: 0) {
                        trafficItem(icon: "arrow.up", label: "Отправлено", value: vpnManager.bytesUp.formattedBytes, color: Color(hex: "#5CFC8A"))
                        Spacer()
                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.5, height: 30)
                        Spacer()
                        trafficItem(icon: "arrow.down", label: "Получено", value: vpnManager.bytesDown.formattedBytes, color: Color(hex: "#5CF0FC"))
                        Spacer()
                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.5, height: 30)
                        Spacer()
                        trafficItem(icon: "antenna.radiowaves.left.and.right", label: "Пинг", value: "—", color: Color(hex: "#FCA85C"))
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.14), accent.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.28), lineWidth: 1))
        )
        .clipped()
        .animation(.easeInOut(duration: 0.4), value: vpnManager.connectionState)
    }

    private func trafficItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundColor(color)
                Text(value).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(color)
            }
            Text(label).font(.system(size: 9)).foregroundColor(Color(hex: "#8A9BB8"))
        }
    }

    // MARK: - Stats Grid (IP карточки)

    private var statsGrid: some View {
        HStack(spacing: 10) {
            IPCard(title: "Реальный IP", info: vpnManager.realIP, icon: "wifi", accentColor: Color(hex: "#8A9BB8"))
            IPCard(
                title: "VPN IP",
                info: vpnManager.vpnIP,
                icon: "lock.shield.fill",
                accentColor: vpnManager.connectionState == .connected ? Color(hex: "#5CFC8A") : Color(hex: "#666680"),
                isEmpty: vpnManager.connectionState != .connected
            )
        }
    }

    // MARK: - Server / Input

    private var serverOrInputSection: some View {
        VStack(spacing: 8) {
            // Поле ввода — всегда видно
            linkInputSection

            // Карточка выбранного сервера — если есть
            if let server = settings.selectedServer {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(server.protocol.accentColor.opacity(0.15))
                        Image(systemName: server.protocol.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(server.protocol.accentColor)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white).lineLimit(1)
                        Text("\(server.protocol.displayName) · \(server.host):\(server.port)")
                            .font(.system(size: 10)).foregroundColor(Color(hex: "#8A9BB8"))
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(server.protocol.accentColor)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#131320"))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(server.protocol.accentColor.opacity(0.25), lineWidth: 1))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35), value: settings.selectedServer?.id)
    }

    // MARK: - Link Input

    private var linkInputSection: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "link").font(.system(size: 13)).foregroundColor(Color(hex: "#5CF0FC"))
                TextField("vless:// vmess:// trojan:// ss://", text: $linkText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($linkFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Готово") { linkFocused = false }
                                .foregroundColor(Color(hex: "#5CF0FC")).fontWeight(.semibold)
                        }
                    }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11).fill(Color(hex: "#131320"))
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(linkFocused ? Color(hex: "#5CF0FC").opacity(0.5) : Color(hex: "#2A2A3E"), lineWidth: 1))
            )

            Button { pasteAndParse() } label: {
                Image(systemName: "doc.on.clipboard").font(.system(size: 14)).foregroundColor(Color(hex: "#5CF0FC"))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "#131320"))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color(hex: "#2A2A3E"), lineWidth: 1))
            }
            if !linkText.isEmpty {
                Button { parseLink() } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 14)).foregroundColor(Color(hex: "#5CFC8A"))
                        .frame(width: 40, height: 40)
                        .background(Color(hex: "#131320"))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color(hex: "#2A2A3E"), lineWidth: 1))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: linkText.isEmpty)
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        Button { handleConnect() } label: {
            HStack(spacing: 10) {
                if isAnimating {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.85)
                } else {
                    Image(systemName: vpnManager.connectionState == .connected ? "stop.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(connectButtonLabel).font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(connectButtonGradient)
                    .shadow(color: connectButtonShadow.opacity(0.45), radius: 14, y: 5)
            )
        }
        .disabled(isAnimating)
        .animation(.spring(response: 0.3), value: vpnManager.connectionState)
    }

    // MARK: - Helpers

    private var isAnimating: Bool { vpnManager.connectionState == .connecting || vpnManager.connectionState == .disconnecting }

    private var orbIcon: String {
        switch vpnManager.connectionState {
        case .connected: return "lock.shield.fill"
        case .connecting, .disconnecting: return "arrow.trianglehead.2.clockwise"
        case .disconnected: return "shield.fill"
        case .error: return "exclamationmark.shield.fill"
        }
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
        case .connected: return LinearGradient(colors: [Color(hex: "#FC5C7D"), Color(hex: "#c02040")], startPoint: .leading, endPoint: .trailing)
        case .connecting, .disconnecting: return LinearGradient(colors: [Color(hex: "#FCA85C"), Color(hex: "#c06020")], startPoint: .leading, endPoint: .trailing)
        default: return LinearGradient(colors: [Color(hex: "#7C5CFC"), Color(hex: "#5C3CCC")], startPoint: .leading, endPoint: .trailing)
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
        if let str = UIPasteboard.general.string, !str.isEmpty { linkText = str; parseLink() }
        else { withAnimation { toast = ToastMessage(text: "Буфер обмена пуст", style: .info) } }
    }
    private func parseLink() {
        guard !linkText.isEmpty else { return }
        do {
            let server = try LinkParser.parse(linkText)
            settings.addServer(server); settings.selectedServerID = server.id; linkText = ""
            withAnimation { toast = ToastMessage(text: "Сервер добавлен: \(server.name)", style: .success) }
        } catch {
            withAnimation { toast = ToastMessage(text: error.localizedDescription, style: .error) }
        }
    }
}

// MARK: - Sub-views

struct IPCard: View {
    let title: String; let info: IPInfo?; let icon: String; let accentColor: Color
    var isEmpty: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundColor(accentColor)
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundColor(Color(hex: "#8A9BB8"))
            }
            if isEmpty {
                Text("—").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "#444460"))
            } else if let info = info {
                Text(info.ip).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                if let country = info.country, let city = info.city {
                    Text("\(country) · \(city)").font(.system(size: 9)).foregroundColor(Color(hex: "#8A9BB8")).lineLimit(1)
                }
            } else {
                HStack(spacing: 4) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: accentColor)).scaleEffect(0.55)
                    Text("Загрузка...").font(.system(size: 10)).foregroundColor(Color(hex: "#666680"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#131320"))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(isEmpty ? 0.08 : 0.2), lineWidth: 1))
        )
    }
}

struct ConnectionTimerView: View {
    let since: Date
    let color: Color
    @State private var elapsed: String = "00:00:00"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        Text(elapsed)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(color)
            .onReceive(timer) { _ in
                let i = Int(Date().timeIntervalSince(since))
                elapsed = String(format: "%02d:%02d:%02d", i/3600, i%3600/60, i%60)
            }
    }
}
