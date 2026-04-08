import Foundation
import SwiftUI

// LibXray wrapper - calls gomobile ObjC class at runtime
// gomobile generates class "LibxrayXray" with methods runXray/stopXray/initGCPercent
// We use runtime dispatch to avoid compile-time dependency on exact class name
private func libxrayRun(_ configBase64: String) -> String {
    // Try known gomobile naming patterns
    let classNames = ["LibxrayXray", "Libxray", "LibXrayXray", "LibXray"]
    for name in classNames {
        guard let cls = NSClassFromString(name) as? NSObject.Type else { continue }
        let sel = NSSelectorFromString("runXray:")
        if cls.responds(to: sel) {
            let result = cls.perform(sel, with: configBase64)?.takeUnretainedValue() as? String
            return result ?? ""
        }
        // Try instance method
        let obj = cls.init()
        if obj.responds(to: sel) {
            let result = obj.perform(sel, with: configBase64)?.takeUnretainedValue() as? String
            return result ?? ""
        }
    }
    return "error: LibXray class not found"
}

private func libxrayStop() {
    let classNames = ["LibxrayXray", "Libxray", "LibXrayXray", "LibXray"]
    for name in classNames {
        guard let cls = NSClassFromString(name) as? NSObject.Type else { continue }
        let sel = NSSelectorFromString("stopXray")
        if cls.responds(to: sel) { cls.perform(sel); return }
        let obj = cls.init()
        if obj.responds(to: sel) { obj.perform(sel); return }
    }
}

private func libxrayGC() {
    let classNames = ["LibxrayXray", "Libxray", "LibXrayXray", "LibXray"]
    for name in classNames {
        guard let cls = NSClassFromString(name) as? NSObject.Type else { continue }
        let sel = NSSelectorFromString("initGCPercent:")
        if cls.responds(to: sel) { cls.perform(sel, with: -1 as AnyObject); return }
        let obj = cls.init()
        if obj.responds(to: sel) { obj.perform(sel, with: -1 as AnyObject); return }
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
    private var gcTimer: Timer?
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
                let config = try XrayConfigBuilder.build(server: server, settings: SettingsStore.shared)
                guard let data = config.data(using: .utf8) else {
                    self.handleError("Ошибка кодирования конфига"); return
                }

                let resultBase64 = libxrayRun(data.base64EncodedString())
                let resultStr: String
                if let d = Data(base64Encoded: resultBase64), let s = String(data: d, encoding: .utf8) {
                    resultStr = s
                } else { resultStr = resultBase64 }

                if !resultStr.isEmpty && resultStr.lowercased().contains("error") {
                    self.handleError(resultStr); return
                }

                self.xrayRunning = true
                self.addLog("xray запущен", level: .info)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, self.xrayRunning else { return }
                    withAnimation(.spring()) { self.connectionState = .connected }
                    self.connectedAt = Date()
                    self.startTimers()
                    self.fetchVPNIP()
                    self.addLog("Успешно подключено", level: .info)
                }
            } catch { self.handleError(error.localizedDescription) }
        }
    }

    func disconnect() {
        DispatchQueue.main.async { withAnimation(.spring()) { self.connectionState = .disconnecting } }
        addLog("Отключение...", level: .info)
        stopTimers()
        xrayQueue.async { [weak self] in libxrayStop(); self?.xrayRunning = false }
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
            self.addLog("Ошибка: \(msg)", level: .error)
            self.xrayRunning = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
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
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.simulateStats() }
        gcTimer    = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.connectionState == .connected else { return }
            libxrayGC()
        }
    }

    private func stopTimers() { statsTimer?.invalidate(); statsTimer = nil; gcTimer?.invalidate(); gcTimer = nil }
    private func simulateStats() { bytesUp += Int64.random(in: 800...8000); bytesDown += Int64.random(in: 2000...30000) }

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
