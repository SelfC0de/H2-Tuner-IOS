import SwiftUI

// MARK: - DNS

enum DNSMode: String, CaseIterable, Identifiable {
    case auto      = "auto"
    case cloudflare = "1.1.1.1"
    case google    = "8.8.8.8"
    case system    = "system"
    case custom    = "custom"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto:       return "Auto"
        case .cloudflare: return "1.1.1.1"
        case .google:     return "8.8.8.8"
        case .system:     return "System"
        case .custom:     return "Custom"
        }
    }
    var icon: String {
        switch self {
        case .auto:       return "⚙️"
        case .cloudflare: return "🟠"
        case .google:     return "🔵"
        case .system:     return "🖥️"
        case .custom:     return "✏️"
        }
    }
    var primaryDNS: String {
        switch self {
        case .auto:       return "localhost"
        case .cloudflare: return "1.1.1.1"
        case .google:     return "8.8.8.8"
        case .system:     return "localhost"
        case .custom:     return ""
        }
    }
}

// MARK: - Routing Mode

enum RoutingMode: String, CaseIterable, Identifiable {
    case global    = "global"
    case bypassRu  = "bypass_ru"
    case direct    = "direct"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .global:   return "Global"
        case .bypassRu: return "Bypass RU"
        case .direct:   return "Direct"
        }
    }
    var subtitle: String {
        switch self {
        case .global:   return "Весь трафик через VPN"
        case .bypassRu: return "Банки и Госуслуги — прямой IP"
        case .direct:   return "Весь трафик напрямую"
        }
    }
    var icon: String {
        switch self {
        case .global:   return "globe"
        case .bypassRu: return "building.columns.fill"
        case .direct:   return "arrow.right.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .global:   return Color(hex: "#7C5CFC")
        case .bypassRu: return Color(hex: "#FC5C7D")
        case .direct:   return Color(hex: "#5CFC8A")
        }
    }
}

// MARK: - RU Bypass Domains

let ruBypassDomains: [String] = [
    "gosuslugi.ru", "mos.ru", "nalog.ru", "pfr.gov.ru", "fss.gov.ru",
    "rosreestr.gov.ru", "mvd.ru", "cbr.ru", "gov.ru",
    "sberbank.ru", "sbrf.ru", "vtb.ru", "alfabank.ru", "tinkoff.ru",
    "raiffeisen.ru", "gazprombank.ru", "rshb.ru", "otkritie.ru",
    "rosbank.ru", "sovcombank.ru", "mts-bank.ru", "psbank.ru",
    "pochtabank.ru", "uralsib.ru", "bspb.ru",
    "mir.ru", "nspk.ru", "sbp.ru",
    "wildberries.ru", "ozon.ru", "avito.ru", "yandex.ru", "mail.ru",
    "vk.com", "ok.ru", "2gis.ru",
]


// MARK: - SettingsStore

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    // Servers
    @Published var savedServers: [ServerConfig] = [] { didSet { saveServers() } }
    @Published var selectedServerID: UUID? {
        didSet {
            if let id = selectedServerID { UserDefaults.standard.set(id.uuidString, forKey: "selectedServerID") }
            else { UserDefaults.standard.removeObject(forKey: "selectedServerID") }
        }
    }

    // Connection
    @Published var autoConnect: Bool = false { didSet { ud("autoConnect", autoConnect) } }
    @Published var enableMux:   Bool = false { didSet { ud("enableMux",   enableMux)   } }
    @Published var sniffEnabled: Bool = true { didSet { ud("sniffEnabled", sniffEnabled) } }

    // DNS — single source of truth
    @Published var dnsMode: DNSMode = .auto {
        didSet { UserDefaults.standard.set(dnsMode.rawValue, forKey: "dnsMode") }
    }
    @Published var dnsCustomValue: String = "" {
        didSet { UserDefaults.standard.set(dnsCustomValue, forKey: "dnsCustomValue") }
    }

    // Routing — single source of truth (replaces bypassLocal + bypassRuServices)
    @Published var routingMode: RoutingMode = .bypassRu {
        didSet { UserDefaults.standard.set(routingMode.rawValue, forKey: "routingMode") }
    }
    @Published var bypassLan: Bool = true { didSet { ud("bypassLan", bypassLan) } }

    // Logs
    @Published var logLevel: String = "warning" { didSet { UserDefaults.standard.set(logLevel, forKey: "logLevel") } }

    // Computed
    var effectiveDNS: String {
        switch dnsMode {
        case .auto, .system: return "localhost"
        case .custom: return dnsCustomValue.isEmpty ? "1.1.1.1" : dnsCustomValue
        default: return dnsMode.primaryDNS
        }
    }

    // Legacy compat for XrayConfigBuilder
    var bypassLocal: Bool { bypassLan }
    var bypassRuServices: Bool { routingMode == .bypassRu }
    var dnsServer: String { effectiveDNS }

    var selectedServer: ServerConfig? { savedServers.first { $0.id == selectedServerID } }

    private func ud(_ key: String, _ val: Bool) { UserDefaults.standard.set(val, forKey: key) }

    private init() {
        loadServers()
        autoConnect   = UserDefaults.standard.object(forKey: "autoConnect")   as? Bool ?? false
        enableMux     = UserDefaults.standard.object(forKey: "enableMux")     as? Bool ?? false
        sniffEnabled  = UserDefaults.standard.object(forKey: "sniffEnabled")  as? Bool ?? true
        bypassLan     = UserDefaults.standard.object(forKey: "bypassLan")     as? Bool ?? true
        logLevel      = UserDefaults.standard.string(forKey: "logLevel")      ?? "warning"
        dnsCustomValue = UserDefaults.standard.string(forKey: "dnsCustomValue") ?? ""
        if let raw = UserDefaults.standard.string(forKey: "dnsMode"), let m = DNSMode(rawValue: raw) { dnsMode = m }
        if let raw = UserDefaults.standard.string(forKey: "routingMode"), let m = RoutingMode(rawValue: raw) { routingMode = m }
        if let idStr = UserDefaults.standard.string(forKey: "selectedServerID"), let id = UUID(uuidString: idStr) { selectedServerID = id }
    }

    private func saveServers() {
        if let data = try? JSONEncoder().encode(savedServers) { UserDefaults.standard.set(data, forKey: "savedServers") }
    }
    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: "savedServers"),
           let servers = try? JSONDecoder().decode([ServerConfig].self, from: data) { savedServers = servers }
    }
    func addServer(_ server: ServerConfig)    { savedServers.append(server) }
    func removeServer(_ server: ServerConfig) {
        savedServers.removeAll { $0.id == server.id }
        if selectedServerID == server.id { selectedServerID = savedServers.first?.id }
    }
    func updateServer(_ server: ServerConfig) {
        if let idx = savedServers.firstIndex(where: { $0.id == server.id }) { savedServers[idx] = server }
    }
}
