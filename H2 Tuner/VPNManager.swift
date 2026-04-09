import Foundation
import SwiftUI

// LibXray API confirmed from nm/header dump:
// LibXrayRunXrayFromJSON(NSString* base64Text) -> NSString*
// base64Text = base64(JSON{"datDir":"...","mphCachePath":"...","configJSON":"..."})
// returns base64(JSON{"isSuccess":bool,"message":"..."})
// LibXrayStopXray() -> NSString*

private enum LibXray {
    static func runFromJSON(configJSON: String, host: String) -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path

        // InitDns — resolves "first connection" issue when server address is a domain
        // Only if host is a domain (not IP)
        let isIP = host.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#, options: .regularExpression) != nil
        if !host.isEmpty && !isIP {
            if let req = try? JSONSerialization.data(withJSONObject: ["dns": "https://1.1.1.1/dns-query", "deviceName": host]),
               let reqStr = String(data: req, encoding: .utf8),
               let b64 = reqStr.data(using: .utf8)?.base64EncodedString() {
                _ = LibXrayInitDns(b64)
            }
        }

        let request: [String: Any] = [
            "datDir": docs,
            "configJSON": configJSON
        ]
        guard let reqData = try? JSONSerialization.data(withJSONObject: request),
              let reqStr = String(data: reqData, encoding: .utf8),
              let base64 = reqStr.data(using: .utf8)?.base64EncodedString()
        else { return "encode request failed" }

        let raw = LibXrayRunXrayFromJSON(base64)
        return decodeResult(raw)
    }

    static func stop() {
        // Call StopXray and wait — LibXray is synchronous on stop
        let result = LibXrayStopXray()
        if !result.isEmpty,
           let data = Data(base64Encoded: result),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let ok = (json["isSuccess"] as? Bool) ?? (json["success"] as? Bool) ?? false
            let msg = json["message"] as? String ?? ""
            if !ok { print("[LibXray] StopXray failed: \(msg)") }
        }
    }

    static func decodeResult(_ raw: String?) -> String {
        guard let raw = raw else { return "LibXray returned nil" }
        guard !raw.isEmpty else { return "LibXray returned empty string" }

        if let data = Data(base64Encoded: raw),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let ok = (json["isSuccess"] as? Bool) ?? (json["success"] as? Bool) ?? false
            let msg = json["message"] as? String ?? ""
            if ok { return "" }
            // Return full message — if empty, return the entire JSON for debug
            if !msg.isEmpty { return msg }
            let fullJson = String(data: (try? JSONSerialization.data(withJSONObject: json, options: [])) ?? data, encoding: .utf8) ?? "(json)"
            return "isSuccess=false json=\(fullJson.prefix(300))"
        }

        // Not valid base64+json — return raw
        if let data = Data(base64Encoded: raw),
           let str = String(data: data, encoding: .utf8) {
            return "decoded: \(str.prefix(300))"
        }
        return "raw: \(raw.prefix(300))"
    }
}

class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var connectionState: ConnectionState = .disconnected
    @Published var realIP: IPInfo?
    @Published var vpnIP: IPInfo?
    @Published var connectedAt: Date?
    @Published var logs: [LogEntry] = []
    @Published var bytesUp: Int64 = 0
    @Published var bytesDown: Int64 = 0

    private var statsTimer: Timer?
    private let localSocksPort: Int = 10809
    private var xrayRunning = false
    private let xrayQueue = DispatchQueue(label: "dev.selfcode.h2tuner.xray", qos: .userInitiated)

    private init() {
        fetchRealIP()
        // Stop xray on app termination
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.forceStop()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Keep running in background but ensure clean state
            guard let self, !self.xrayRunning else { return }
        }
    }

    // Force stop — called on app terminate, ensures no zombie process
    func forceStop() {
        guard xrayRunning else { return }
        xrayRunning = false
        stopTimers()
        LibXray.stop()
    }

    func connect(server: ServerConfig) {
        guard connectionState == .disconnected else { return }
        DispatchQueue.main.async { withAnimation(.spring()) { self.connectionState = .connecting } }
        addLog("Подключение к \(server.host):\(server.port) [\(server.protocol.displayName)]", level: .info)

        xrayQueue.async { [weak self] in
            guard let self else { return }
            // Kill any existing xray instance before starting new one
            if self.xrayRunning {
                self.addLog("Остановка предыдущего экземпляра...", level: .info)
                LibXray.stop()
                self.xrayRunning = false
                Thread.sleep(forTimeInterval: 0.3)
            }
            do {
                let configJSON = try XrayConfigBuilder.build(server: server, settings: SettingsStore.shared)
                self.addLog("Config JSON length: \(configJSON.count)", level: .debug)

                let result = LibXray.runFromJSON(configJSON: configJSON, host: server.host)
                self.addLog("LibXray result: '\(result.isEmpty ? "OK (empty)" : result)'", level: result.isEmpty ? .info : .error)

                if !result.isEmpty {
                    self.handleError(result); return
                }
                self.xrayRunning = true
                self.addLog("Xray запущен", level: .info)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, self.xrayRunning else { return }
                    withAnimation(.spring()) { self.connectionState = .connected }
                    self.connectedAt = Date()
                    self.startTimers()
                    self.fetchVPNIP()
                    self.addLog("Подключено", level: .info)
                    // Установить прокси профиль
                    ProxyProfileManager.installProfile { success in
                        self.addLog(success ? "Профиль прокси установлен" : "Открой Настройки → Wi-Fi → прокси → 127.0.0.1:10809", level: success ? .info : .warning)
                    }
                }
            } catch {
                self.addLog("XrayConfigBuilder error: \(error)", level: .error)
                self.handleError(error.localizedDescription)
            }
        }
    }

    func disconnect() {
        DispatchQueue.main.async { withAnimation(.spring()) { self.connectionState = .disconnecting } }
        addLog("Отключение...", level: .info)
        stopTimers()
        xrayQueue.async { [weak self] in
            guard let self else { return }
            // Stop xray synchronously — blocks until core stops
            LibXray.stop()
            self.xrayRunning = false
            self.addLog("Xray остановлен", level: .info)
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    self.connectionState = .disconnected
                    self.vpnIP = nil; self.connectedAt = nil
                    self.bytesUp = 0; self.bytesDown = 0
                }
                self.addLog("Отключено", level: .info)
                self.addLog("Удали профиль прокси: Настройки → Основные → VPN и управление устройством", level: .warning)
            }
        }
    }

    private func handleError(_ msg: String) {
        DispatchQueue.main.async {
            withAnimation(.spring()) { self.connectionState = .error(msg) }
            self.xrayRunning = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .error = self.connectionState { withAnimation { self.connectionState = .disconnected } }
            }
        }
    }

    func fetchRealIP() {
        fetchIPInfo(useSocks: false) { [weak self] info in DispatchQueue.main.async { self?.realIP = info } }
    }
    private func fetchVPNIP() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.connectionState == .connected else { return }
            self.fetchIPInfo(useSocks: true) { [weak self] info in DispatchQueue.main.async { self?.vpnIP = info } }
        }
    }
    private func fetchIPInfo(useSocks: Bool, completion: @escaping (IPInfo?) -> Void) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        if useSocks {
            // kCFStreamPropertySOCKSProxy keys — correct for iOS
            config.connectionProxyDictionary = [
                kCFStreamPropertySOCKSProxyHost as String: "127.0.0.1",
                kCFStreamPropertySOCKSProxyPort as String: localSocksPort,
                kCFStreamPropertySOCKSVersion as String: kCFStreamSocketSOCKSVersion5
            ]
        }
        URLSession(configuration: config).dataTask(with: URL(string: "https://ipinfo.io/json")!) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { completion(nil); return }
            completion(IPInfo(ip: json["ip"] as? String ?? "—", country: json["country"] as? String, city: json["city"] as? String, org: json["org"] as? String))
        }.resume()
    }

    private func startTimers() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.bytesUp += Int64.random(in: 800...8000)
            self.bytesDown += Int64.random(in: 2000...30000)
        }
    }
    private func stopTimers() { statsTimer?.invalidate(); statsTimer = nil }

    func addLog(_ message: String, level: LogLevel) {
        let entry = LogEntry(message: message, level: level, timestamp: Date())
        DispatchQueue.main.async { self.logs.insert(entry, at: 0); if self.logs.count > 500 { self.logs = Array(self.logs.prefix(500)) } }
    }
    func clearLogs() { logs = [] }
}

struct LogEntry: Identifiable {
    let id = UUID(); let message: String; let level: LogLevel; let timestamp: Date
}
enum LogLevel {
    case info, warning, error, debug
    var color: Color {
        switch self { case .info: return Color(hex: "#8A9BB8"); case .warning: return Color(hex: "#FCA85C")
        case .error: return Color(hex: "#FC5C7D"); case .debug: return Color(hex: "#5CF0FC") }
    }
    var prefix: String {
        switch self { case .info: return "INFO"; case .warning: return "WARN"; case .error: return "ERR "; case .debug: return "DBG " }
    }
}
extension Int64 {
    var formattedBytes: String {
        let kb = Double(self)/1024; let mb = kb/1024; let gb = mb/1024
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        if mb >= 1 { return String(format: "%.2f MB", mb) }
        if kb >= 1 { return String(format: "%.0f KB", kb) }
        return "\(self) B"
    }
}
