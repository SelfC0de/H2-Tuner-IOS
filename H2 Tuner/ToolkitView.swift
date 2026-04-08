import SwiftUI

struct ToolkitItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: ToolkitAction
}

enum ToolkitAction {
    case ipInfo
    case pingTest
    case dnsLookup
    case speedTest
    case qrScan
    case shareConfig
    case clearLogs
    case exportConfig
}

struct ToolkitView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var settings: SettingsStore
    @Binding var toast: ToastMessage?

    @State private var pingResult: String? = nil
    @State private var dnsQuery: String = ""
    @State private var dnsResult: String? = nil
    @State private var isPinging = false
    @State private var isDNSLooking = false
    @State private var activeCard: ToolkitAction? = nil
    @FocusState private var dnsFieldFocused: Bool

    private let tools: [ToolkitItem] = [
        ToolkitItem(title: "IP Info",       subtitle: "Текущий IP и геолокация",     icon: "location.fill",          color: Color(hex: "#5CF0FC"), action: .ipInfo),
        ToolkitItem(title: "Ping Test",     subtitle: "Проверить задержку сервера",  icon: "waveform.path.ecg",      color: Color(hex: "#5CFC8A"), action: .pingTest),
        ToolkitItem(title: "DNS Lookup",    subtitle: "Разрешить доменное имя",      icon: "magnifyingglass.circle", color: Color(hex: "#FCA85C"), action: .dnsLookup),
        ToolkitItem(title: "Speed Test",    subtitle: "Измерить скорость соединения",icon: "speedometer",            color: Color(hex: "#7C5CFC"), action: .speedTest),
        ToolkitItem(title: "QR Код",        subtitle: "Сканировать VPN конфиг",      icon: "qrcode.viewfinder",      color: Color(hex: "#FC5C7D"), action: .qrScan),
        ToolkitItem(title: "Очистить логи", subtitle: "Удалить все записи логов",    icon: "trash.fill",             color: Color(hex: "#FC5C7D"), action: .clearLogs),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerBar.padding(.top, 60).padding(.horizontal, 20)

                // Tools grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(tools) { tool in
                        ToolCard(item: tool, isActive: activeCard == tool.action) {
                            handleTool(tool.action)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Expanded result panels
                if activeCard == .pingTest {
                    pingPanel.padding(.horizontal, 20).transition(.opacity.combined(with: .move(edge: .top)))
                }
                if activeCard == .dnsLookup {
                    dnsPanel.padding(.horizontal, 20).transition(.opacity.combined(with: .move(edge: .top)))
                }
                if activeCard == .ipInfo {
                    ipInfoPanel.padding(.horizontal, 20).transition(.opacity.combined(with: .move(edge: .top)))
                }
                if activeCard == .speedTest {
                    speedTestPanel.padding(.horizontal, 20).transition(.opacity.combined(with: .move(edge: .top)))
                }

                // RU Bypass list
                ruBypassSection.padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .animation(.spring(response: 0.35), value: activeCard)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("Инструменты")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            if vpnManager.connectionState == .connected {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "#5CFC8A")).frame(width: 7, height: 7)
                        .shadow(color: Color(hex: "#5CFC8A").opacity(0.8), radius: 3)
                    Text("VPN активен").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#5CFC8A"))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color(hex: "#5CFC8A").opacity(0.1))
                    .overlay(Capsule().stroke(Color(hex: "#5CFC8A").opacity(0.3), lineWidth: 1)))
            }
        }
    }

    // MARK: - Tool panels

    private var pingPanel: some View {
        ResultPanel(title: "Ping Test", icon: "waveform.path.ecg", color: Color(hex: "#5CFC8A")) {
            VStack(alignment: .leading, spacing: 12) {
                if let server = settings.selectedServer {
                    Text("Сервер: \(server.host):\(server.port)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "#8A9BB8"))
                }
                if isPinging {
                    HStack(spacing: 8) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#5CFC8A"))).scaleEffect(0.8)
                        Text("Измерение...").font(.system(size: 13)).foregroundColor(Color(hex: "#8A9BB8"))
                    }
                } else if let result = pingResult {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "#5CFC8A"))
                        Text(result).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    }
                }
                Button {
                    runPing()
                } label: {
                    Label("Запустить", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#5CFC8A"))
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(Color(hex: "#5CFC8A").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isPinging)
            }
        }
    }

    private var dnsPanel: some View {
        ResultPanel(title: "DNS Lookup", icon: "magnifyingglass.circle", color: Color(hex: "#FCA85C")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    TextField("google.com", text: $dnsQuery)
                        .font(.system(size: 13, design: .monospaced)).foregroundColor(.white)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .focused($dnsFieldFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Готово") { dnsFieldFocused = false }
                                    .foregroundColor(Color(hex: "#FCA85C")).fontWeight(.semibold)
                            }
                        }
                    Button { runDNS() } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22)).foregroundColor(Color(hex: "#FCA85C"))
                    }
                    .disabled(isDNSLooking || dnsQuery.isEmpty)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(hex: "#111120")).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#FCA85C").opacity(0.3), lineWidth: 1))

                if isDNSLooking {
                    HStack(spacing: 8) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FCA85C"))).scaleEffect(0.8)
                        Text("Запрос...").font(.system(size: 13)).foregroundColor(Color(hex: "#8A9BB8"))
                    }
                } else if let result = dnsResult {
                    Text(result)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "#FCA85C"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var ipInfoPanel: some View {
        ResultPanel(title: "IP Info", icon: "location.fill", color: Color(hex: "#5CF0FC")) {
            VStack(spacing: 10) {
                ipInfoRow(label: "Реальный IP", info: vpnManager.realIP, color: Color(hex: "#8A9BB8"))
                if vpnManager.connectionState == .connected {
                    Divider().background(Color(hex: "#2A2A3E"))
                    ipInfoRow(label: "VPN IP", info: vpnManager.vpnIP, color: Color(hex: "#5CFC8A"))
                }
                Button {
                    vpnManager.fetchRealIP()
                    withAnimation { toast = ToastMessage(text: "Обновление IP...", style: .info) }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#5CF0FC"))
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(Color(hex: "#5CF0FC").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func ipInfoRow(label: String, info: IPInfo?, color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(Color(hex: "#8A9BB8"))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(info?.ip ?? "—").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
                if let c = info?.country, let city = info?.city {
                    Text("\(c) · \(city)").font(.system(size: 10)).foregroundColor(color)
                }
            }
        }
    }

    private var speedTestPanel: some View {
        ResultPanel(title: "Speed Test", icon: "speedometer", color: Color(hex: "#7C5CFC")) {
            VStack(spacing: 8) {
                Text("Откроет внешний сервис speedtest.net")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#8A9BB8"))
                Button {
                    if let url = URL(string: "https://fast.com") { UIApplication.shared.open(url) }
                } label: {
                    Label("Открыть fast.com", systemImage: "arrow.up.right.square")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#7C5CFC"))
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(Color(hex: "#7C5CFC").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - RU Bypass section

    private var ruBypassSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "#8A9BB8"))
                Text("ПРЯМОЙ ДОСТУП (БЕЗ VPN)").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "#8A9BB8")).kerning(0.8)
                Spacer()
                Toggle("", isOn: $settings.bypassRuServices).labelsHidden().tint(Color(hex: "#FC5C7D")).scaleEffect(0.8)
            }
            .padding(.leading, 4)

            if settings.bypassRuServices {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(ruBypassCategories, id: \.title) { cat in
                        HStack(spacing: 6) {
                            Text(cat.emoji).font(.system(size: 14))
                            Text(cat.title).font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#8A9BB8")).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color(hex: "#1A1A2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2A2A3E"), lineWidth: 1))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3), value: settings.bypassRuServices)
    }

    // MARK: - Actions

    private func handleTool(_ action: ToolkitAction) {
        withAnimation(.spring(response: 0.3)) {
            activeCard = activeCard == action ? nil : action
        }
        switch action {
        case .clearLogs:
            vpnManager.clearLogs()
            withAnimation { toast = ToastMessage(text: "Логи очищены", style: .success) }
            activeCard = nil
        case .qrScan:
            withAnimation { toast = ToastMessage(text: "QR сканер — скоро", style: .info) }
            activeCard = nil
        default: break
        }
    }

    private func runPing() {
        guard let server = settings.selectedServer else {
            withAnimation { toast = ToastMessage(text: "Сначала выберите сервер", style: .warning) }
            return
        }
        isPinging = true; pingResult = nil
        let host = server.host
        let start = Date()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: config)
        let url = URL(string: "https://\(host)")!
        session.dataTask(with: url) { _, _, _ in
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            DispatchQueue.main.async {
                isPinging = false
                pingResult = "\(ms) ms"
            }
        }.resume()
    }

    private func runDNS() {
        guard !dnsQuery.isEmpty else { return }
        isDNSLooking = true; dnsResult = nil
        let host = dnsQuery
        DispatchQueue.global().async {
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            var res: UnsafeMutablePointer<addrinfo>? = nil
            let err = getaddrinfo(host, nil, &hints, &res)
            var addresses: [String] = []
            if err == 0 {
                var ptr = res
                while let p = ptr {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(p.pointee.ai_addr, p.pointee.ai_addrlen, &hostname, socklen_t(NI_MAXHOST), nil, 0, NI_NUMERICHOST) == 0 {
                        let addr = String(cString: hostname)
                        if !addresses.contains(addr) { addresses.append(addr) }
                    }
                    ptr = p.pointee.ai_next
                }
                freeaddrinfo(res)
            }
            DispatchQueue.main.async {
                isDNSLooking = false
                dnsResult = addresses.isEmpty ? "Не найдено" : addresses.joined(separator: "\n")
            }
        }
    }
}

// MARK: - Supporting views

struct ToolCard: View {
    let item: ToolkitItem
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(item.color.opacity(isActive ? 0.25 : 0.12))
                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(item.color)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    Text(item.subtitle).font(.system(size: 10)).foregroundColor(Color(hex: "#666680")).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#1A1A2E"))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(isActive ? item.color.opacity(0.5) : Color(hex: "#2A2A3E"), lineWidth: 1))
            )
            .shadow(color: isActive ? item.color.opacity(0.2) : Color.clear, radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isActive ? 0.97 : 1.0)
        .animation(.spring(response: 0.25), value: isActive)
    }
}

struct ResultPanel<Content: View>: View {
    let title: String; let icon: String; let color: Color
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(color)
                Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#1A1A2E"))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3), lineWidth: 1)))
    }
}

struct BypassCategory { let emoji: String; let title: String }
let ruBypassCategories: [BypassCategory] = [
    .init(emoji: "🏛️", title: "Госуслуги"),
    .init(emoji: "🏦", title: "Банки РФ"),
    .init(emoji: "💳", title: "МИР/СБП"),
    .init(emoji: "🛒", title: "Маркетплейсы"),
    .init(emoji: "📱", title: "VK / Mail"),
    .init(emoji: "🗺️", title: "2ГИС / Яндекс"),
]
