import SwiftUI
import Combine

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var savedServers: [ServerConfig] = [] {
        didSet { saveServers() }
    }

    @Published var autoConnect: Bool = false {
        didSet { UserDefaults.standard.set(autoConnect, forKey: "autoConnect") }
    }

    @Published var bypassLocal: Bool = true {
        didSet { UserDefaults.standard.set(bypassLocal, forKey: "bypassLocal") }
    }

    @Published var enableMux: Bool = false {
        didSet { UserDefaults.standard.set(enableMux, forKey: "enableMux") }
    }

    @Published var dnsServer: String = "1.1.1.1" {
        didSet { UserDefaults.standard.set(dnsServer, forKey: "dnsServer") }
    }

    @Published var sniffEnabled: Bool = true {
        didSet { UserDefaults.standard.set(sniffEnabled, forKey: "sniffEnabled") }
    }

    @Published var logLevel: String = "warning" {
        didSet { UserDefaults.standard.set(logLevel, forKey: "logLevel") }
    }

    @Published var selectedServerID: UUID? {
        didSet {
            if let id = selectedServerID {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedServerID")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedServerID")
            }
        }
    }

    var selectedServer: ServerConfig? {
        savedServers.first { $0.id == selectedServerID }
    }

    private init() {
        loadServers()
        autoConnect = UserDefaults.standard.bool(forKey: "autoConnect")
        bypassLocal = UserDefaults.standard.object(forKey: "bypassLocal") as? Bool ?? true
        enableMux = UserDefaults.standard.bool(forKey: "enableMux")
        dnsServer = UserDefaults.standard.string(forKey: "dnsServer") ?? "1.1.1.1"
        sniffEnabled = UserDefaults.standard.object(forKey: "sniffEnabled") as? Bool ?? true
        logLevel = UserDefaults.standard.string(forKey: "logLevel") ?? "warning"
        if let idStr = UserDefaults.standard.string(forKey: "selectedServerID"),
           let id = UUID(uuidString: idStr) {
            selectedServerID = id
        }
    }

    private func saveServers() {
        if let data = try? JSONEncoder().encode(savedServers) {
            UserDefaults.standard.set(data, forKey: "savedServers")
        }
    }

    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: "savedServers"),
           let servers = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            savedServers = servers
        }
    }

    func addServer(_ server: ServerConfig) {
        savedServers.append(server)
    }

    func removeServer(_ server: ServerConfig) {
        savedServers.removeAll { $0.id == server.id }
        if selectedServerID == server.id {
            selectedServerID = savedServers.first?.id
        }
    }

    func updateServer(_ server: ServerConfig) {
        if let idx = savedServers.firstIndex(where: { $0.id == server.id }) {
            savedServers[idx] = server
        }
    }
}
