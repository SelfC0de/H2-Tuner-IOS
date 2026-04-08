import Foundation
import SwiftUI

class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var connectionState: ConnectionState = .disconnected
    @Published var realIP: IPInfo?
    @Published var vpnIP: IPInfo?
    @Published var connectedAt: Date?
    @Published var logs: [LogEntry] = []
    @Published var bytesUp: Int64 = 0
    @Published var bytesDown: Int64 = 0

    private var xrayPID: pid_t = 0
    private var statsTimer: Timer?
    private var watchdogTimer: Timer?
    private let localSocksPort: Int = 10809
    private var configFilePath: String?
    private let logQueue = DispatchQueue(label: "dev.selfcode.h2tuner.logs", qos: .utility)

    private init() { fetchRealIP() }

    func connect(server: ServerConfig) {
        guard connectionState == .disconnected else { return }
        DispatchQueue.main.async { withAnimation(.spring()) { self.connectionState = .connecting } }
        addLog("Подключение к \(server.host):\(server.port) [\(server.protocol.displayName)]", level: .info)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let config = try XrayConfigBuilder.build(server: server, settings: SettingsStore.shared)
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("xray_cfg_\(UUID().uuidString).json")
                try config.write(to: tmpURL, atomically: true, encoding: .utf8)
                self.configFilePath = tmpURL.path

                guard let xrayPath = self.resolveXrayPath() else {
                    self.handleError("xray binary не найден в Bundle")
                    return
                }

                let pid = self.launchXray(executablePath: xrayPath, configPath: tmpURL.path)
                guard pid > 0 else {
                    self.handleError("Не удалось запустить xray (posix_spawn failed)")
                    return
                }
                self.xrayPID = pid
                self.addLog("xray запущен (PID \(pid))", level: .info)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self else { return }
                    if self.xrayIsRunning() {
                        withAnimation(.spring()) { self.connectionState = .connected }
                        self.connectedAt = Date()
                        self.startTimers()
                        self.fetchVPNIP()
                        self.addLog("Успешно подключено", level: .info)
                    } else {
                        self.handleError("xray завершился сразу после запуска")
                    }
                }

            } catch {
                self.handleError(error.localizedDescription)
            }
        }
    }

    func disconnect() {
        DispatchQueue.main.async { withAnimation(.spring()) { self.connectionState = .disconnecting } }
        addLog("Отключение...", level: .info)
        stopTimers()
        killXray()
        if let path = configFilePath {
            try? FileManager.default.removeItem(atPath: path)
            configFilePath = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring()) {
                self.connectionState = .disconnected
                self.vpnIP = nil
                self.connectedAt = nil
                self.bytesUp = 0
                self.bytesDown = 0
            }
            self.addLog("Отключено", level: .info)
        }
    }

    // MARK: - posix_spawn launcher

    private func launchXray(executablePath: String, configPath: String) -> pid_t {
        var pid: pid_t = 0
        let args: [String] = [executablePath, "run", "-c", configPath]
        let cArgs = args.map { $0.withCString(strdup) } + [nil]
        defer { cArgs.compactMap { $0 }.forEach { free($0) } }

        let env: [String] = ["PATH=/usr/bin:/bin"]
        let cEnv = env.map { $0.withCString(strdup) } + [nil]
        defer { cEnv.compactMap { $0 }.forEach { free($0) } }

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP))

        let result = posix_spawn(&pid, executablePath, nil, &attr,
                                 cArgs.map { UnsafeMutablePointer(mutating: $0) },
                                 cEnv.map { UnsafeMutablePointer(mutating: $0) })
        posix_spawnattr_destroy(&attr)
        return result == 0 ? pid : 0
    }

    private func killXray() {
        guard xrayPID > 0 else { return }
        kill(xrayPID, SIGTERM)
        xrayPID = 0
    }

    private func xrayIsRunning() -> Bool {
        guard xrayPID > 0 else { return false }
        return kill(xrayPID, 0) == 0
    }

    // MARK: - Helpers

    private func resolveXrayPath() -> String? {
        let candidates = [
            Bundle.main.path(forResource: "xray", ofType: nil),
            Bundle.main.bundlePath + "/xray"
        ]
        for path in candidates.compactMap({ $0 }) where FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: path)
            return path
        }
        return nil
    }

    private func handleError(_ msg: String) {
        DispatchQueue.main.async {
            withAnimation(.spring()) { self.connectionState = .error(msg) }
            self.addLog("Ошибка: \(msg)", level: .error)
            self.killXray()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if case .error = self.connectionState {
                    withAnimation { self.connectionState = .disconnected }
                }
            }
        }
    }

    func fetchRealIP() {
        fetchIPInfo(useSocks: false) { [weak self] info in
            DispatchQueue.main.async { self?.realIP = info }
        }
    }

    private func fetchVPNIP() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.connectionState == .connected else { return }
            self.fetchIPInfo(useSocks: true) { [weak self] info in
                DispatchQueue.main.async { self?.vpnIP = info }
            }
        }
    }

    private func fetchIPInfo(useSocks: Bool, completion: @escaping (IPInfo?) -> Void) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        if useSocks {
            config.connectionProxyDictionary = [
                "SOCKSEnable": 1,
                "SOCKSProxy": "127.0.0.1",
                "SOCKSPort": localSocksPort
            ]
        }
        let session = URLSession(configuration: config)
        guard let url = URL(string: "https://ipinfo.io/json") else { completion(nil); return }
        session.dataTask(with: url) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil); return
            }
            completion(IPInfo(
                ip: json["ip"] as? String ?? "—",
                country: json["country"] as? String,
                city: json["city"] as? String,
                org: json["org"] as? String
            ))
        }.resume()
    }

    private func startTimers() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.simulateStats()
        }
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, self.connectionState == .connected else { return }
            if !self.xrayIsRunning() {
                self.handleError("xray неожиданно завершился")
            }
        }
    }

    private func stopTimers() {
        statsTimer?.invalidate(); statsTimer = nil
        watchdogTimer?.invalidate(); watchdogTimer = nil
    }

    private func simulateStats() {
        bytesUp += Int64.random(in: 800...8000)
        bytesDown += Int64.random(in: 2000...30000)
    }

    func addLog(_ message: String, level: LogLevel) {
        let entry = LogEntry(message: message, level: level, timestamp: Date())
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
            if self.logs.count > 500 { self.logs = Array(self.logs.prefix(500)) }
        }
    }

    func clearLogs() { logs = [] }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let level: LogLevel
    let timestamp: Date
}

enum LogLevel {
    case info, warning, error, debug

    var color: Color {
        switch self {
        case .info:    return Color(hex: "#8A9BB8")
        case .warning: return Color(hex: "#FCA85C")
        case .error:   return Color(hex: "#FC5C7D")
        case .debug:   return Color(hex: "#5CF0FC")
        }
    }

    var prefix: String {
        switch self {
        case .info:    return "INFO"
        case .warning: return "WARN"
        case .error:   return "ERR "
        case .debug:   return "DBG "
        }
    }
}

extension Int64 {
    var formattedBytes: String {
        let kb = Double(self) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        if mb >= 1 { return String(format: "%.2f MB", mb) }
        if kb >= 1 { return String(format: "%.0f KB", kb) }
        return "\(self) B"
    }
}
