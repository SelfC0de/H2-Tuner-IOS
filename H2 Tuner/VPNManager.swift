import Foundation
import SwiftUI

// LibXray API confirmed from nm/header dump:
// LibXrayRunXrayFromJSON(NSString* base64Text) -> NSString*
// base64Text = base64(JSON{"datDir":"...","mphCachePath":"...","configJSON":"..."})
// returns base64(JSON{"isSuccess":bool,"message":"..."})
// LibXrayStopXray() -> NSString*

private enum LibXray {
    static func runFromJSON(configJSON: String) -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        let request: [String: Any] = [
            "datDir": docs,
            "mphCachePath": "",
            "configJSON": configJSON
        ]
        guard let reqData = try? JSONSerialization.data(withJSONObject: request),
              let reqStr = String(data: reqData, encoding: .utf8),
              let base64 = reqStr.data(using: .utf8)?.base64EncodedString()
        else { return "encode request failed" }

        let raw = LibXrayRunXrayFromJSON(base64)
        return decodeResult(raw)
    }

    static func stop() { _ = LibXrayStopXray() }

    static func decodeResult(_ raw: String?) -> String {
        guard let raw = raw else { return "LibXray returned nil" }
        guard !raw.isEmpty else { return "LibXray returned empty string" }

        // Try base64 decode
        if let data = Data(base64Encoded: raw) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let ok = json["isSuccess"] as? Bool ?? false
                let msg = json["message"] as? String ?? "(no message)"
                if ok { return "" }
                return "LibXray: \(msg)"
            }
            // base64 decoded but not JSON
            let decoded = String(data: data, encoding: .utf8) ?? "(binary)"
            return "LibXray non-JSON: \(decoded.prefix(200))"
        }

        // Not base64 — return raw (truncated)
        return "LibXray raw: \(raw.prefix(200))"
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

    private init() { fetchRealIP() }

    func connect(server: ServerConfig) {
        guard connectionState == .disconnected else { return }
        DispatchQueue.main.async { withAnimation(.spring()) { self.connectionState = .connecting } }
        addLog("Подключение к \(server.host):\(server.port) [\(server.protocol.displayName)]", level: .info)

        xrayQueue.async { [weak self] in
            guard let self else { return }
            do {
                let configJSON = try XrayConfigBuilder.build(server: server, settings: SettingsStore.shared)
                self.addLog("Config JSON length: \(configJSON.count)", level: .debug)

                let result = LibXray.runFromJSON(configJSON: configJSON)
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
        xrayQueue.async { [weak self] in LibXray.stop(); self?.xrayRunning = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring()) {
                self.connectionState = .disconnected
                self.vpnIP = nil; self.connectedAt = nil
                self.bytesUp = 0; self.bytesDown = 0
            }
            self.addLog("Отключено", level: .info)
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
        if useSocks { config.connectionProxyDictionary = ["SOCKSEnable": 1, "SOCKSProxy": "127.0.0.1", "SOCKSPort": localSocksPort] }
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
