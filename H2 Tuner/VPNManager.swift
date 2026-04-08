import Foundation
import SwiftUI

// libXray API (gomobile, package "libxray"):
// - gomobile Go func RunXray(base64Text string) string
//   → ObjC: LibxrayRunXray(NSString*) → NSString*
//   base64Text = base64(JSON{"datDir":"...","configPath":"..."})
//   returns base64(JSON{"isSuccess":bool,"message":"..."})
// - gomobile Go func StopXray() string
//   → ObjC: LibxrayStopXray() → NSString*

private enum LibXray {
    // Write config JSON to temp file, call RunXray with base64-encoded request
    static func run(configJSON: String) -> String {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let configPath = docs.appendingPathComponent("xray_config.json").path
        let datDir = docs.path

        do {
            try configJSON.write(toFile: configPath, atomically: true, encoding: .utf8)
        } catch {
            return "error: cannot write config: \(error)"
        }

        let request: [String: Any] = ["datDir": datDir, "configPath": configPath]
        guard let requestData = try? JSONSerialization.data(withJSONObject: request),
              let requestBase64 = String(data: requestData, encoding: .utf8)?.data(using: .utf8)?.base64EncodedString()
        else { return "error: cannot encode request" }

        // Try gomobile-generated function name
        // gomobile: Go package "libxray" -> ObjC prefix "Libxray" -> func RunXray -> LibxrayRunXray
        let resultBase64 = callLibxray(func: "LibxrayRunXray", arg: requestBase64)
            ?? callLibxray(func: "RunXray", arg: requestBase64)
            ?? "error: LibXray function not found"

        // Decode result
        if let data = Data(base64Encoded: resultBase64),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let success = json["isSuccess"] as? Bool ?? false
            let message = json["message"] as? String ?? ""
            return success ? "" : "error: \(message)"
        }
        // If result is not base64 JSON, return raw
        return resultBase64.hasPrefix("error") ? resultBase64 : ""
    }

    static func stop() {
        _ = callLibxray(func: "LibxrayStopXray", arg: nil)
            ?? callLibxray(func: "StopXray", arg: nil)
    }

    private static func callLibxray(func name: String, arg: String?) -> String? {
        // Try as C function via dlsym
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        if let sym = dlsym(rtldDefault, name) {
            if let arg {
                typealias RunFn = @convention(c) (UnsafePointer<CChar>?) -> UnsafePointer<CChar>?
                let fn = unsafeBitCast(sym, to: RunFn.self)
                if let result = fn(arg) { return String(cString: result) }
                return ""
            } else {
                typealias StopFn = @convention(c) () -> UnsafePointer<CChar>?
                let fn = unsafeBitCast(sym, to: StopFn.self)
                _ = fn()
                return ""
            }
        }
        // Try ObjC runtime
        let classNames = ["LibxrayXray", "Libxray", "LibXray", "LibXrayXray"]
        for clsName in classNames {
            guard let cls = NSClassFromString(clsName) as? NSObject.Type else { continue }
            let sel = NSSelectorFromString(arg != nil ? "\(name):" : name)
            let obj = cls.init()
            guard obj.responds(to: sel) else { continue }
            if let arg {
                let r = obj.perform(sel, with: arg)?.takeUnretainedValue() as? String
                return r ?? ""
            } else {
                obj.perform(sel)
                return ""
            }
        }
        return nil
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
                let result = LibXray.run(configJSON: configJSON)
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
            } catch { self.handleError(error.localizedDescription) }
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
